import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const String defaultHomePageUrl = 'https://www.google.com';

void main() {
  runApp(const MarkdownBrowserApp());
}

class MarkdownBrowserApp extends StatelessWidget {
  const MarkdownBrowserApp({super.key, this.enableNativeWebView = true});

  final bool enableNativeWebView;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f6f73),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff5f7f7),
        visualDensity: VisualDensity.compact,
      ),
      home: BrowserWorkspace(enableNativeWebView: enableNativeWebView),
    );
  }
}

enum ViewMode {
  web('Web', Icons.public),
  reader('Reader', Icons.chrome_reader_mode_outlined),
  markdown('Markdown', Icons.notes),
  editor('Editor', Icons.edit_note),
  source('Source', Icons.code);

  const ViewMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class PageMetadata {
  const PageMetadata({
    required this.title,
    required this.description,
    required this.author,
    required this.published,
    required this.sourceUrl,
    required this.siteName,
  });

  final String title;
  final String description;
  final String author;
  final String published;
  final String sourceUrl;
  final String siteName;
}

class PageDocument {
  PageDocument({
    required this.url,
    required this.rawHtml,
    required this.extractedText,
    required this.markdown,
    required this.metadata,
    required this.outline,
    required this.links,
    required this.images,
    required this.warnings,
  });

  final String url;
  final String rawHtml;
  final String extractedText;
  String markdown;
  final PageMetadata metadata;
  final List<String> outline;
  final List<String> links;
  final List<String> images;
  final List<String> warnings;
}

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.title,
    this.currentUrl = '',
    this.document,
    this.savedMarkdown,
    this.savedFilePath,
    this.viewMode = ViewMode.markdown,
  });

  final String id;
  String title;
  String currentUrl;
  PageDocument? document;
  String? savedMarkdown;
  String? savedFilePath;
  ViewMode viewMode;

  String get displayedMarkdown => savedMarkdown ?? document?.markdown ?? '';
}

enum LibrarySection {
  bookmarks('Bookmarks', Icons.bookmark_border),
  history('History', Icons.history),
  saved('Saved', Icons.description_outlined);

  const LibrarySection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class PageLinkEntry {
  const PageLinkEntry({required this.url, required this.title});

  final String url;
  final String title;

  String get displayTitle {
    final trimmedTitle = title.trim();
    return trimmedTitle.isEmpty ? url : trimmedTitle;
  }

  factory PageLinkEntry.fromJson(Object? value) {
    if (value is String) {
      return PageLinkEntry(url: value, title: '');
    }
    if (value is Map) {
      final json = Map<String, Object?>.from(value);
      return PageLinkEntry(
        url: json['url'] is String ? json['url'] as String : '',
        title: json['title'] is String ? json['title'] as String : '',
      );
    }
    return const PageLinkEntry(url: '', title: '');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'url': url, 'title': title};
  }
}

class SavedPageEntry {
  const SavedPageEntry({
    required this.url,
    required this.title,
    required this.contentHash,
    required this.localizedContentHash,
    required this.filePath,
    required this.savedAt,
    required this.allLocal,
  });

  final String url;
  final String title;
  final String contentHash;
  final String localizedContentHash;
  final String filePath;
  final DateTime savedAt;
  final bool allLocal;

  factory SavedPageEntry.fromJson(Object? value) {
    if (value is! Map) {
      return SavedPageEntry(
        url: '',
        title: '',
        contentHash: '',
        localizedContentHash: '',
        filePath: '',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
        allLocal: false,
      );
    }
    final json = Map<String, Object?>.from(value);
    return SavedPageEntry(
      url: json['url'] is String ? json['url'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      contentHash: json['contentHash'] is String
          ? json['contentHash'] as String
          : '',
      localizedContentHash: json['localizedContentHash'] is String
          ? json['localizedContentHash'] as String
          : '',
      filePath: json['filePath'] is String ? json['filePath'] as String : '',
      savedAt:
          DateTime.tryParse(
            json['savedAt'] is String ? json['savedAt'] as String : '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      allLocal: json['allLocal'] is bool ? json['allLocal'] as bool : false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'title': title,
    'contentHash': contentHash,
    'localizedContentHash': localizedContentHash,
    'filePath': filePath,
    'savedAt': savedAt.toIso8601String(),
    'allLocal': allLocal,
  };
}

class SavedPageContentStore {
  static File markdownFile(SavedPageEntry entry) => File(entry.filePath);

  static Directory assetDirectory(SavedPageEntry entry) {
    final file = markdownFile(entry);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final baseName = fileName.replaceFirst(
      RegExp(r'\.(md|markdown)$', caseSensitive: false),
      '',
    );
    return Directory(
      '${file.parent.path}${Platform.pathSeparator}${baseName}_assets',
    );
  }

  static Future<List<String>> existingPaths(SavedPageEntry entry) async {
    if (entry.filePath.trim().isEmpty) return const <String>[];
    final paths = <String>[];
    final markdown = markdownFile(entry);
    final assets = assetDirectory(entry);
    if (await _existsBestEffort(markdown)) paths.add(markdown.path);
    if (await _existsBestEffort(assets)) paths.add(assets.path);
    return paths;
  }

  static Future<bool> _existsBestEffort(FileSystemEntity entity) async {
    try {
      return await entity.exists();
    } on FileSystemException {
      // An unavailable or previously removed parent folder must not prevent
      // the saved-page entry itself from being removed from the app.
      return false;
    }
  }

  static Future<void> deleteIfPresent(SavedPageEntry entry) async {
    if (entry.filePath.trim().isEmpty) return;
    await _deleteIfPresent(markdownFile(entry));
    await _deleteIfPresent(assetDirectory(entry));
  }

  static Future<void> _deleteIfPresent(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: entity is Directory);
      }
    } on FileSystemException {
      // A user or a sync process may remove the target between the existence
      // check and deletion. That already satisfies the requested outcome.
      if (await entity.exists()) rethrow;
    }
  }
}

class PersistedAppState {
  const PersistedAppState({
    required this.bookmarks,
    required this.history,
    required this.savedPages,
    required this.lastSaveDirectory,
    required this.homePageUrl,
    required this.saveAllLocally,
  });

  final List<PageLinkEntry> bookmarks;
  final List<PageLinkEntry> history;
  final List<SavedPageEntry> savedPages;
  final String? lastSaveDirectory;
  final String homePageUrl;
  final bool saveAllLocally;

  factory PersistedAppState.empty() {
    return const PersistedAppState(
      bookmarks: <PageLinkEntry>[],
      history: <PageLinkEntry>[],
      savedPages: <SavedPageEntry>[],
      lastSaveDirectory: null,
      homePageUrl: defaultHomePageUrl,
      saveAllLocally: true,
    );
  }

  factory PersistedAppState.fromJson(Map<String, Object?> json) {
    final rawSettings = json['settings'];
    final settings = rawSettings is Map
        ? Map<String, Object?>.from(rawSettings)
        : <String, Object?>{};
    return PersistedAppState(
      bookmarks: _pageLinkList(json['bookmarks']),
      history: _pageLinkList(json['history']),
      savedPages: _savedPageList(json['savedPages']),
      lastSaveDirectory: settings['lastSaveDirectory'] is String
          ? settings['lastSaveDirectory'] as String
          : null,
      homePageUrl: settings['homePageUrl'] is String
          ? settings['homePageUrl'] as String
          : defaultHomePageUrl,
      saveAllLocally: settings['saveAllLocally'] is bool
          ? settings['saveAllLocally'] as bool
          : true,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 2,
      'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      'history': history.map((entry) => entry.toJson()).toList(),
      'savedPages': savedPages.map((entry) => entry.toJson()).toList(),
      'settings': <String, Object?>{
        'lastSaveDirectory': lastSaveDirectory,
        'homePageUrl': homePageUrl,
        'saveAllLocally': saveAllLocally,
      },
    };
  }

  static List<PageLinkEntry> _pageLinkList(Object? value) {
    if (value is! List<Object?>) {
      return <PageLinkEntry>[];
    }
    return value
        .map(PageLinkEntry.fromJson)
        .where((entry) => entry.url.isNotEmpty)
        .toList();
  }

  static List<SavedPageEntry> _savedPageList(Object? value) {
    if (value is! List<Object?>) return <SavedPageEntry>[];
    return value
        .map(SavedPageEntry.fromJson)
        .where((entry) => entry.url.isNotEmpty && entry.contentHash.isNotEmpty)
        .toList();
  }
}

class AppStateStore {
  Future<PersistedAppState> load() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return PersistedAppState.empty();
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return PersistedAppState.empty();
    }
    return PersistedAppState.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> save(PersistedAppState state) async {
    final file = await _stateFile();
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(state.toJson()));
  }

  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/app_state.json');
  }
}

class WorkspaceAccess {
  static const MethodChannel _channel = MethodChannel(
    'markdown_browser/workspace',
  );

  static Future<String?> restore() async {
    if (!Platform.isMacOS) return null;
    try {
      return await _channel.invokeMethod<String>('resolveBookmark');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String?> choose() async {
    if (!Platform.isMacOS) {
      return getDirectoryPath(confirmButtonText: 'Use workspace');
    }
    return _channel.invokeMethod<String>('chooseWorkspace');
  }

  static Future<void> remember(String path) async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<String>('saveBookmark', <String, String>{
      'path': path,
    });
  }

  static Future<void> forget() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('clearBookmark');
    } on PlatformException {
      // The local path setting is still cleared if the native bookmark is gone.
    }
  }
}

class WorkspaceData {
  const WorkspaceData({
    required this.bookmarks,
    required this.history,
    required this.homePageUrl,
    required this.saveAllLocally,
  });

  final List<PageLinkEntry> bookmarks;
  final List<PageLinkEntry> history;
  final String? homePageUrl;
  final bool? saveAllLocally;
}

class WorkspaceStore {
  WorkspaceStore._(this.rootPath);

  final String rootPath;

  String get articlesPath => '$rootPath/Articles';
  String get dataPath => '$rootPath/MarkdownBrowser Data';
  String get bookmarksPath => '$dataPath/bookmarks';
  String get historyPath => '$dataPath/history';
  String get devicesPath => '$dataPath/devices';
  String get deviceId {
    final host = Platform.localHostname.trim().isEmpty
        ? 'device'
        : Platform.localHostname.trim();
    return sha256.convert(utf8.encode(host)).toString().substring(0, 12);
  }

  static Future<WorkspaceStore> open(String rootPath) async {
    final store = WorkspaceStore._(rootPath);
    for (final path in <String>[
      store.articlesPath,
      store.bookmarksPath,
      store.historyPath,
      store.devicesPath,
    ]) {
      await Directory(path).create(recursive: true);
    }
    final manifest = File('${store.dataPath}/workspace.json');
    if (!await manifest.exists()) {
      await store._writeJson(manifest, <String, Object?>{
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'settings': <String, Object?>{},
      });
    }
    await store._writeJson(
      File('${store.devicesPath}/${store.deviceId}.json'),
      <String, Object?>{
        'id': store.deviceId,
        'name': Platform.localHostname,
        'platform': Platform.operatingSystem,
        'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return store;
  }

  Future<void> verifyWritable() async {
    final probe = File(
      '$dataPath/.write-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probe.writeAsString('ok', flush: true);
    } finally {
      if (await probe.exists()) await probe.delete();
    }
  }

  Future<WorkspaceData> load() async {
    final bookmarks = <PageLinkEntry>[];
    await for (final entity in Directory(bookmarksPath).list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        final entry = PageLinkEntry.fromJson(decoded);
        if (entry.url.isNotEmpty) bookmarks.add(entry);
      } catch (_) {
        // A cloud conflict or partial file must not prevent workspace loading.
      }
    }

    final historyByUrl = <String, PageLinkEntry>{};
    await for (final entity in Directory(historyPath).list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! List) continue;
        for (final value in decoded) {
          final entry = PageLinkEntry.fromJson(value);
          if (entry.url.isNotEmpty) historyByUrl[entry.url] = entry;
        }
      } catch (_) {
        // Other device history remains optional when a file is conflicted.
      }
    }

    String? homePageUrl;
    bool? saveAllLocally;
    try {
      final decoded = jsonDecode(
        await File('$dataPath/workspace.json').readAsString(),
      );
      if (decoded is Map) {
        final settings = decoded['settings'];
        if (settings is Map) {
          homePageUrl = settings['homePageUrl'] as String?;
          saveAllLocally = settings['saveAllLocally'] as bool?;
        }
      }
    } catch (_) {
      // Defaults and local bootstrap settings remain available.
    }
    return WorkspaceData(
      bookmarks: bookmarks,
      history: historyByUrl.values.toList(),
      homePageUrl: homePageUrl,
      saveAllLocally: saveAllLocally,
    );
  }

  Future<void> save({
    required List<PageLinkEntry> bookmarks,
    required List<PageLinkEntry> history,
    required String homePageUrl,
    required bool saveAllLocally,
  }) async {
    final desiredBookmarkFiles = <String>{};
    for (final bookmark in bookmarks) {
      final name = '${sha256.convert(utf8.encode(bookmark.url))}.json';
      desiredBookmarkFiles.add(name);
      await _writeJson(File('$bookmarksPath/$name'), bookmark.toJson());
    }
    await for (final entity in Directory(bookmarksPath).list()) {
      if (entity is File &&
          entity.path.endsWith('.json') &&
          !desiredBookmarkFiles.contains(entity.uri.pathSegments.last)) {
        await entity.delete();
      }
    }
    await _writeJson(
      File('$historyPath/$deviceId.json'),
      history.map((entry) => entry.toJson()).toList(),
    );
    await _writeJson(File('$dataPath/workspace.json'), <String, Object?>{
      'version': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': <String, Object?>{
        'homePageUrl': homePageUrl,
        'saveAllLocally': saveAllLocally,
      },
    });
  }

  Future<void> _writeJson(File file, Object value) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(value), flush: true);
  }
}

class BrowserWorkspace extends StatefulWidget {
  const BrowserWorkspace({super.key, required this.enableNativeWebView});

  final bool enableNativeWebView;

  @override
  State<BrowserWorkspace> createState() => _BrowserWorkspaceState();
}

class _BrowserWorkspaceState extends State<BrowserWorkspace> {
  static const int _maxHistoryItems = 200;

  final AppStateStore _appStateStore = AppStateStore();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _homePageController = TextEditingController();
  final TextEditingController _markdownController = TextEditingController();
  final List<BrowserTab> _tabs = <BrowserTab>[
    BrowserTab(id: 'tab-1', title: 'New page'),
  ];
  final List<SavedPageEntry> _savedPages = <SavedPageEntry>[];
  final List<PageLinkEntry> _history = <PageLinkEntry>[];
  final List<PageLinkEntry> _bookmarks = <PageLinkEntry>[];
  WebViewController? _webViewController;
  WorkspaceStore? _workspace;
  String? _workspaceRoot;
  String? _localSaveDirectory;
  String _homePageUrl = defaultHomePageUrl;
  int _activeIndex = 0;
  LibrarySection _activeLibrarySection = LibrarySection.bookmarks;
  bool _showLibraryRail = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isLoading = false;
  bool _isSavingLocal = false;
  bool _showInsightPanel = false;
  bool _saveAllLocally = true;
  String? _statusMessage;

  BrowserTab get _activeTab => _tabs[_activeIndex];

  @override
  void initState() {
    super.initState();
    _homePageController.text = _homePageUrl;
    if (widget.enableNativeWebView) {
      _initializeWebView();
    }
    _loadPersistedAppState();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _htmlController.dispose();
    _homePageController.dispose();
    _markdownController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedAppState() async {
    try {
      final state = await _appStateStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(state.bookmarks);
        _history
          ..clear()
          ..addAll(state.history.take(_maxHistoryItems));
        _savedPages
          ..clear()
          ..addAll(state.savedPages);
        _homePageUrl = _normalizeAddress(state.homePageUrl);
        _homePageController.text = _homePageUrl;
        _saveAllLocally = state.saveAllLocally;
        if (state.bookmarks.isNotEmpty || state.history.isNotEmpty) {
          _statusMessage = 'Loaded app bookmarks and history.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Could not load app state: $error';
      });
    }
    final restoredWorkspace = await WorkspaceAccess.restore();
    if (restoredWorkspace != null) {
      try {
        final workspace = await WorkspaceStore.open(restoredWorkspace);
        final data = await workspace.load();
        if (!mounted) return;
        setState(() {
          _workspace = workspace;
          _workspaceRoot = restoredWorkspace;
          _localSaveDirectory = workspace.articlesPath;
          if (data.bookmarks.isNotEmpty) {
            _bookmarks
              ..clear()
              ..addAll(data.bookmarks);
          }
          if (data.history.isNotEmpty) {
            _history
              ..clear()
              ..addAll(data.history.take(_maxHistoryItems));
          }
          if (data.homePageUrl != null) {
            _homePageUrl = _normalizeAddress(data.homePageUrl!);
            _homePageController.text = _homePageUrl;
          }
          if (data.saveAllLocally != null) {
            _saveAllLocally = data.saveAllLocally!;
          }
          _statusMessage = 'Workspace restored: $restoredWorkspace';
        });
      } catch (error) {
        if (mounted) {
          setState(() {
            _workspace = null;
            _workspaceRoot = null;
            _localSaveDirectory = null;
            _statusMessage = 'Workspace could not be restored: $error';
          });
        }
      }
    }
    if (_workspace != null) {
      await _persistAppState();
    }
    await _discoverSavedPages();
    if (mounted) {
      await _openHomePage(loadWebView: widget.enableNativeWebView);
    }
  }

  Future<void> _persistAppState() async {
    try {
      await _appStateStore.save(
        PersistedAppState(
          bookmarks: _bookmarks,
          history: _history.take(_maxHistoryItems).toList(),
          savedPages: _savedPages,
          lastSaveDirectory: _workspaceRoot,
          homePageUrl: _homePageUrl,
          saveAllLocally: _saveAllLocally,
        ),
      );
      await _workspace?.save(
        bookmarks: _bookmarks,
        history: _history.take(_maxHistoryItems).toList(),
        homePageUrl: _homePageUrl,
        saveAllLocally: _saveAllLocally,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Could not save app state: $error';
      });
    }
  }

  void _recordHistory(String url, String title) {
    final entry = PageLinkEntry(
      url: url,
      title: title == 'New page' ? '' : title.trim(),
    );
    _history.removeWhere((item) => item.url == url);
    _history.insert(0, entry);
    if (_history.length > _maxHistoryItems) {
      _history.removeRange(_maxHistoryItems, _history.length);
    }
  }

  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MarkdownBrowserContextMenu',
        onMessageReceived: _handleContextMenuMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _statusMessage = 'Loading $url';
              _activeTab.currentUrl = url;
              _addressController.text = url;
            });
          },
          onPageFinished: _extractCurrentWebPage,
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || !mounted) {
              return;
            }
            setState(() {
              _activeTab.currentUrl = url;
              _addressController.text = url;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) {
              return;
            }
            setState(() {
              _isLoading = false;
              _statusMessage = 'WebView error: ${error.description}';
            });
          },
        ),
      );
  }

  Future<void> _handleContextMenuMessage(JavaScriptMessage message) async {
    if (!mounted) {
      return;
    }
    final decoded = jsonDecode(message.message);
    if (decoded is! Map) {
      return;
    }
    final payload = Map<String, Object?>.from(decoded);
    final url = payload['url'] is String ? payload['url'] as String : '';
    if (url.isEmpty) {
      return;
    }
    final title = payload['title'] is String ? payload['title'] as String : '';
    final x = payload['x'] is num ? (payload['x'] as num).toDouble() : 24.0;
    final y = payload['y'] is num ? (payload['y'] as num).toDouble() : 96.0;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final leftOffset = _showLibraryRail ? 250.0 : 0.0;
    final topOffset = 118.0;
    final position = RelativeRect.fromLTRB(
      (x + leftOffset).clamp(8.0, overlay.size.width - 8.0),
      (y + topOffset).clamp(8.0, overlay.size.height - 8.0),
      8,
      8,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(value: 'new_tab', child: Text('新しいタブで開く')),
      ],
    );
    if (action == 'new_tab') {
      await _openLinkInNewTab(url: url, title: title);
    }
  }

  Future<void> _installContextMenuHandler(WebViewController controller) async {
    await controller.runJavaScript(r'''
      (function () {
        if (window.__markdownBrowserContextMenuInstalled) {
          return;
        }
        window.__markdownBrowserContextMenuInstalled = true;
        document.addEventListener('contextmenu', function (event) {
          var target = event.target;
          var anchor = target && target.closest ? target.closest('a[href]') : null;
          if (!anchor || !anchor.href) {
            return;
          }
          event.preventDefault();
          MarkdownBrowserContextMenu.postMessage(JSON.stringify({
            url: anchor.href,
            title: (anchor.innerText || anchor.title || anchor.href || '').trim(),
            x: event.clientX,
            y: event.clientY
          }));
        }, true);
      })();
    ''');
  }

  Future<void> _openAddress() async {
    final input = _addressController.text.trim();
    if (input.isEmpty) {
      return;
    }

    final url = _normalizeAddress(input);
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening $url';
    });

    try {
      final controller = _webViewController;
      if (controller == null) {
        throw StateError('Native WebView is disabled in this environment.');
      }
      setState(() {
        _activeTab
          ..currentUrl = url
          ..viewMode = ViewMode.web;
        _addressController.text = url;
      });
      await controller.loadRequest(Uri.parse(url));
    } catch (error) {
      setState(() {
        _statusMessage =
            'Could not open this page in the native WebView. Paste HTML below as a fallback. Details: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _openHomePage({bool loadWebView = true}) async {
    final url = _normalizeAddress(_homePageUrl);
    setState(() {
      _activeTab
        ..currentUrl = url
        ..title = 'Home'
        ..document = null
        ..savedMarkdown = null
        ..savedFilePath = null
        ..viewMode = ViewMode.web;
      _addressController.text = url;
      _markdownController.clear();
      _isLoading = loadWebView && _webViewController != null;
      _statusMessage = 'Home: $url';
    });
    if (!loadWebView) {
      return;
    }
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    try {
      await controller.loadRequest(Uri.parse(url));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not open home page: $error';
      });
    }
  }

  Future<void> _openLinkInNewTab({
    required String url,
    required String title,
  }) async {
    final normalizedUrl = _normalizeAddress(url);
    if (widget.enableNativeWebView) {
      _initializeWebView();
    }
    final tabTitle = title.trim().isEmpty ? 'New tab' : title.trim();
    setState(() {
      _tabs.add(
        BrowserTab(
          id: 'tab-${_tabs.length + 1}',
          title: tabTitle,
          currentUrl: normalizedUrl,
          viewMode: ViewMode.web,
        ),
      );
      _activeIndex = _tabs.length - 1;
      _addressController.text = normalizedUrl;
      _htmlController.clear();
      _markdownController.clear();
      _canGoBack = false;
      _canGoForward = false;
      _isLoading = widget.enableNativeWebView && _webViewController != null;
      _statusMessage = 'Opening in new tab: $normalizedUrl';
    });
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    try {
      await controller.loadRequest(Uri.parse(normalizedUrl));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not open new tab: $error';
      });
    }
  }

  Future<void> _extractCurrentWebPage(String url) async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    try {
      final result = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final rawHtml = _javascriptStringResult(result);
      final document = _convertHtml(url, rawHtml);
      final savedArtifact = await _readSavedArtifact(url);
      if (!mounted) {
        return;
      }
      try {
        await _installContextMenuHandler(controller);
      } catch (_) {
        // Some pages restrict script injection. Markdown extraction still works.
      }
      setState(() {
        _activeTab
          ..currentUrl = url
          ..title = document.metadata.title
          ..document = document
          ..savedMarkdown = savedArtifact?.markdown
          ..savedFilePath = savedArtifact?.filePath;
        _canGoBack = false;
        _canGoForward = false;
        _recordHistory(url, document.metadata.title);
        _markdownController.text = _activeTab.displayedMarkdown;
        _isLoading = false;
        _statusMessage = 'Loaded and converted ${document.metadata.title}';
      });
      await _refreshNavigationState();
      await _persistAppState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Loaded page, but HTML extraction failed: $error';
      });
    }
  }

  Future<({String markdown, String filePath})?> _readSavedArtifact(
    String url,
  ) async {
    SavedPageEntry? entry;
    for (final candidate in _savedPages) {
      if (candidate.url == url) {
        entry = candidate;
        break;
      }
    }
    if (entry == null || entry.filePath.isEmpty) return null;
    final file = File(entry.filePath);
    if (!await file.exists()) return null;
    try {
      final contents = await file.readAsString();
      return (markdown: _markdownBody(contents), filePath: entry.filePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSavedPage(SavedPageEntry entry) async {
    final artifact = await _readSavedArtifact(entry.url);
    if (artifact == null || !mounted) {
      setState(() {
        _statusMessage = 'Saved Markdown file could not be opened.';
      });
      return;
    }
    final document = PageDocument(
      url: entry.url,
      rawHtml: '',
      extractedText: artifact.markdown,
      markdown: artifact.markdown,
      metadata: PageMetadata(
        title: entry.title,
        description: '',
        author: '',
        published: '',
        sourceUrl: entry.url,
        siteName: 'Saved Markdown',
      ),
      outline: const <String>[],
      links: const <String>[],
      images: const <String>[],
      warnings: const <String>[],
    );
    setState(() {
      _activeTab
        ..currentUrl = entry.url
        ..title = entry.title
        ..document = document
        ..savedMarkdown = artifact.markdown
        ..savedFilePath = artifact.filePath
        ..viewMode = ViewMode.markdown;
      _addressController.text = entry.url;
      _markdownController.text = artifact.markdown;
      _statusMessage = 'Opened saved Markdown: ${entry.filePath}';
    });
  }

  static String _markdownBody(String contents) {
    return contents.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
      '',
    );
  }

  String _javascriptStringResult(Object result) {
    final value = result.toString();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value
          .substring(1, value.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll('\\\\', '\\');
    }
    return value;
  }

  void _convertPastedHtml() {
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      setState(() {
        _statusMessage = 'Paste HTML before converting.';
      });
      return;
    }
    final url = _addressController.text.trim().isEmpty
        ? 'local://pasted-html'
        : _normalizeAddress(_addressController.text.trim());
    _navigateTo(url, html);
    setState(() {
      _statusMessage = 'Converted pasted HTML.';
    });
  }

  void _navigateTo(String url, String html) {
    final tab = _activeTab;
    final document = _convertHtml(url, html);
    setState(() {
      tab
        ..currentUrl = url
        ..title = document.metadata.title
        ..document = document
        ..viewMode = ViewMode.markdown;
      _canGoBack = false;
      _canGoForward = false;
      _recordHistory(url, document.metadata.title);
      _addressController.text = url;
      _markdownController.text = document.markdown;
      _isLoading = false;
    });
    _persistAppState();
  }

  Future<void> _goBack() async {
    final controller = _webViewController;
    if (controller == null || !await controller.canGoBack()) {
      await _refreshNavigationState();
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Going back...';
    });
    await controller.goBack();
    await _refreshNavigationState();
  }

  Future<void> _goForward() async {
    final controller = _webViewController;
    if (controller == null || !await controller.canGoForward()) {
      await _refreshNavigationState();
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Going forward...';
    });
    await controller.goForward();
    await _refreshNavigationState();
  }

  Future<void> _refreshNavigationState() async {
    final controller = _webViewController;
    if (controller == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _canGoBack = false;
        _canGoForward = false;
      });
      return;
    }
    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  void _newTab() {
    setState(() {
      _tabs.add(BrowserTab(id: 'tab-${_tabs.length + 1}', title: 'New page'));
      _activeIndex = _tabs.length - 1;
      _addressController.clear();
      _htmlController.clear();
      _markdownController.clear();
      _canGoBack = false;
      _canGoForward = false;
      _statusMessage = null;
    });
  }

  Future<void> _selectTab(int index) async {
    setState(() {
      _activeIndex = index;
      _addressController.text = _activeTab.currentUrl;
      _markdownController.text = _activeTab.displayedMarkdown;
      _canGoBack = false;
      _canGoForward = false;
    });
    if (_activeTab.currentUrl.isNotEmpty &&
        _activeTab.viewMode == ViewMode.web) {
      await _loadActiveTabUrlAsFreshNavigation();
    }
  }

  Future<void> _closeTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      if (_tabs.length == 1) {
        _tabs[0] = BrowserTab(id: 'tab-1', title: 'New page');
        _activeIndex = 0;
      } else {
        _tabs.removeAt(index);
        if (_activeIndex > index) {
          _activeIndex -= 1;
        } else if (_activeIndex >= _tabs.length) {
          _activeIndex = _tabs.length - 1;
        }
      }
      _addressController.text = _activeTab.currentUrl;
      _markdownController.text = _activeTab.displayedMarkdown;
      _canGoBack = false;
      _canGoForward = false;
      _isLoading = false;
      _statusMessage = _activeTab.currentUrl.isEmpty
          ? null
          : 'Switched to ${_activeTab.title}';
    });
    if (_activeTab.currentUrl.isNotEmpty &&
        _activeTab.viewMode == ViewMode.web) {
      await _loadActiveTabUrlAsFreshNavigation();
    }
  }

  Future<void> _loadActiveTabUrlAsFreshNavigation() async {
    final url = _activeTab.currentUrl;
    if (url.isEmpty) {
      return;
    }
    if (widget.enableNativeWebView) {
      _initializeWebView();
    }
    final freshController = _webViewController;
    if (freshController == null) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await freshController.loadRequest(Uri.parse(url));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not reload tab: $error';
      });
    }
  }

  void _setViewMode(ViewMode mode) {
    setState(() {
      if (_activeTab.viewMode == ViewMode.editor) {
        if (_activeTab.savedMarkdown != null) {
          _activeTab.savedMarkdown = _markdownController.text;
        } else {
          _activeTab.document?.markdown = _markdownController.text;
        }
      }
      _activeTab.viewMode = mode;
      if (mode == ViewMode.editor) {
        _markdownController.text = _activeTab.displayedMarkdown;
      }
    });
  }

  Future<void> _saveCurrentPage() async {
    final document = _activeTab.document;
    if (document == null) {
      return;
    }
    final markdown = _markdownController.text.isEmpty
        ? document.markdown
        : _markdownController.text;
    final contentHash = _contentHash(markdown);
    final duplicate = _savedPages.any(
      (page) =>
          page.url == document.url &&
          (!_saveAllLocally || page.allLocal) &&
          (page.contentHash == contentHash ||
              page.localizedContentHash == contentHash),
    );
    if (duplicate) {
      setState(() {
        _statusMessage = 'Already saved: this page has not changed.';
      });
      return;
    }
    if (_localSaveDirectory == null) {
      await _chooseLocalFolder();
      if (_localSaveDirectory == null) {
        setState(() {
          _statusMessage = 'Choose a local save folder before saving.';
        });
        return;
      }
    }

    setState(() {
      _isSavingLocal = true;
      _statusMessage = _saveAllLocally
          ? 'Saving Markdown and local assets...'
          : 'Saving Markdown...';
    });

    try {
      document.markdown = markdown;
      final result = await LocalMarkdownSaver.save(
        directoryPath: _localSaveDirectory!,
        document: document,
        markdown: document.markdown,
        saveAllLocally: _saveAllLocally,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeTab
          ..savedMarkdown = result.markdown
          ..savedFilePath = result.filePath;
        _markdownController.text = result.markdown;
        _savedPages.removeWhere((page) => page.url == document.url);
        _savedPages.insert(
          0,
          SavedPageEntry(
            url: document.url,
            title: document.metadata.title,
            contentHash: contentHash,
            localizedContentHash: _contentHash(result.markdown),
            filePath: result.filePath,
            savedAt: DateTime.now(),
            allLocal: _saveAllLocally,
          ),
        );
        _isSavingLocal = false;
        _statusMessage = result.localizedCount > 0
            ? 'Saved locally: ${result.filePath} (${result.localizedCount} image links updated)'
            : 'Saved locally: ${result.filePath}';
      });
      await _persistAppState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingLocal = false;
        _statusMessage = 'Local save failed: $error';
      });
    }
  }

  Future<void> _localizeImagesInMarkdownFile() async {
    final markdownFile = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: <String>['md', 'markdown']),
      ],
      confirmButtonText: 'Select Markdown',
    );
    if (markdownFile == null || markdownFile.path.isEmpty) {
      return;
    }

    setState(() {
      _isSavingLocal = true;
      _statusMessage = 'Collecting images for ${markdownFile.name}...';
    });

    try {
      final result = await LocalMarkdownSaver.localizeMarkdownFileImages(
        filePath: markdownFile.path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final document = _documentFromMarkdownFile(result);
        _activeTab
          ..currentUrl = Uri.file(result.filePath).toString()
          ..title = result.fileName
          ..document = document
          ..savedMarkdown = result.markdown
          ..savedFilePath = result.filePath
          ..viewMode = ViewMode.editor;
        _addressController.text = _activeTab.currentUrl;
        _markdownController.text = result.markdown;
        _isSavingLocal = false;
        _statusMessage =
            'Image collection complete: ${result.localizedCount}/${result.imageLinkCount} links updated in ${result.filePath}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingLocal = false;
        _statusMessage = 'Image collection failed: $error';
      });
    }
  }

  PageDocument _documentFromMarkdownFile(
    MarkdownImageLocalizationResult result,
  ) {
    final fileUrl = Uri.file(result.filePath).toString();
    return PageDocument(
      url: fileUrl,
      rawHtml: '',
      extractedText: result.markdown,
      markdown: result.markdown,
      metadata: PageMetadata(
        title: result.fileName,
        description: '',
        author: '',
        published: '',
        sourceUrl: fileUrl,
        siteName: 'Local Markdown',
      ),
      outline: const <String>[],
      links: const <String>[],
      images: const <String>[],
      warnings: const <String>[],
    );
  }

  Future<void> _chooseLocalFolder() async {
    String? path;
    try {
      path = await WorkspaceAccess.choose();
    } on MissingPluginException {
      path = await getDirectoryPath(confirmButtonText: 'Use workspace');
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Workspace permission failed: ${error.message}';
        });
      }
      return;
    }
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      if (!Platform.isMacOS) await WorkspaceAccess.remember(path);
      final workspace = await WorkspaceStore.open(path);
      await workspace.verifyWritable();
      final data = await workspace.load();
      await _migrateSavedArticles(workspace);
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _workspaceRoot = path;
        _localSaveDirectory = workspace.articlesPath;
        if (data.bookmarks.isNotEmpty) {
          final byUrl = <String, PageLinkEntry>{
            for (final entry in _bookmarks) entry.url: entry,
            for (final entry in data.bookmarks) entry.url: entry,
          };
          _bookmarks
            ..clear()
            ..addAll(byUrl.values);
        }
        _statusMessage = 'Workspace: $path';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Workspace could not be opened: $error';
      });
      return;
    }
    await _discoverSavedPages();
    await _persistAppState();
  }

  Future<void> _migrateSavedArticles(WorkspaceStore workspace) async {
    for (final saved in _savedPages) {
      if (saved.filePath.isEmpty) continue;
      final source = File(saved.filePath);
      if (!await source.exists() ||
          source.parent.path == workspace.articlesPath) {
        continue;
      }
      final fileName = source.uri.pathSegments.last;
      final destination = File('${workspace.articlesPath}/$fileName');
      if (!await destination.exists()) {
        await source.copy(destination.path);
      }

      final baseName = fileName.replaceFirst(
        RegExp(r'\.(md|markdown)$', caseSensitive: false),
        '',
      );
      final sourceAssets = Directory(
        '${source.parent.path}/${baseName}_assets',
      );
      final destinationAssets = Directory(
        '${workspace.articlesPath}/${baseName}_assets',
      );
      if (await sourceAssets.exists()) {
        await _copyDirectory(sourceAssets, destinationAssets);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (entity is File) {
        final target = File('${destination.path}/$name');
        if (!await target.exists()) await entity.copy(target.path);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory('${destination.path}/$name'));
      }
    }
  }

  Future<void> _discoverSavedPages() async {
    final path = _localSaveDirectory;
    if (path == null || path.isEmpty) return;
    final directory = Directory(path);
    if (!await directory.exists()) return;

    final discovered = <SavedPageEntry>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File ||
            !RegExp(
              r'\.(md|markdown)$',
              caseSensitive: false,
            ).hasMatch(entity.path)) {
          continue;
        }
        final markdown = await entity.readAsString();
        final source = RegExp(
          r'^source:\s*["\x27]?(.+?)["\x27]?\s*$',
          multiLine: true,
        ).firstMatch(markdown)?.group(1);
        if (source == null || source.trim().isEmpty) continue;
        final title =
            RegExp(
              r'^title:\s*["\x27]?(.+?)["\x27]?\s*$',
              multiLine: true,
            ).firstMatch(markdown)?.group(1) ??
            entity.uri.pathSegments.last;
        final body = markdown.replaceFirst(
          RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
          '',
        );
        final modified = await entity.lastModified();
        discovered.add(
          SavedPageEntry(
            url: source.trim(),
            title: title.trim(),
            contentHash: _contentHash(body),
            localizedContentHash: _contentHash(body),
            filePath: entity.path,
            savedAt: modified,
            allLocal: RegExp(r'!\[[^\]]*\]\([^):]+_assets/').hasMatch(body),
          ),
        );
      }
    } on FileSystemException catch (_) {
      if (mounted) {
        setState(() {
          _localSaveDirectory = null;
          _workspace = null;
          _workspaceRoot = null;
          _statusMessage =
              'The saved folder cannot be accessed. Choose the folder again to restore permission.';
        });
        await _persistAppState();
      }
      return;
    }
    if (!mounted || discovered.isEmpty) return;
    setState(() {
      for (final entry in discovered) {
        _savedPages.removeWhere((saved) => saved.url == entry.url);
        _savedPages.add(entry);
      }
      _savedPages.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    });
  }

  void _bookmarkCurrentPage() {
    final url = _activeTab.currentUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _statusMessage = 'Open a page before adding a bookmark.';
      });
      return;
    }
    final title = _activeTab.document?.metadata.title.trim().isNotEmpty == true
        ? _activeTab.document!.metadata.title.trim()
        : _activeTab.title.trim();
    final bookmark = PageLinkEntry(
      url: url,
      title: title == 'New page' ? '' : title,
    );
    setState(() {
      _bookmarks.removeWhere((item) => item.url == url);
      _bookmarks.insert(0, bookmark);
      _statusMessage = 'Bookmarked: ${bookmark.displayTitle}';
    });
    _persistAppState();
  }

  Future<void> _editBookmark(PageLinkEntry bookmark) async {
    final controller = TextEditingController(text: bookmark.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit bookmark'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;
    setState(() {
      final index = _bookmarks.indexWhere((item) => item.url == bookmark.url);
      if (index >= 0) {
        _bookmarks[index] = PageLinkEntry(url: bookmark.url, title: title);
      }
      _statusMessage = 'Bookmark updated.';
    });
    await _persistAppState();
  }

  Future<void> _deleteBookmark(PageLinkEntry bookmark) async {
    setState(() {
      _bookmarks.removeWhere((item) => item.url == bookmark.url);
      _statusMessage = 'Bookmark removed.';
    });
    await _persistAppState();
  }

  Future<void> _deleteHistoryEntry(PageLinkEntry entry) async {
    setState(() {
      _history.removeWhere((item) => item.url == entry.url);
      _statusMessage = 'History entry removed.';
    });
    await _persistAppState();
  }

  Future<bool> _confirmSavedContentDeletion({
    required String title,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Text(
              'The following saved content still exists. Delete it from disk as well?\n\n${paths.join('\n')}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete content'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteSavedPage(SavedPageEntry entry) async {
    final paths = await SavedPageContentStore.existingPaths(entry);
    if (!mounted ||
        !await _confirmSavedContentDeletion(
          title: 'Delete saved page?',
          paths: paths,
        )) {
      return;
    }
    Object? contentDeletionError;
    try {
      await SavedPageContentStore.deleteIfPresent(entry);
    } catch (error) {
      contentDeletionError = error;
    }
    if (!mounted) return;
    setState(() {
      _savedPages.removeWhere((page) => page.url == entry.url);
      for (final tab in _tabs) {
        if (tab.savedFilePath == entry.filePath) {
          tab
            ..savedMarkdown = null
            ..savedFilePath = null;
        }
      }
      _statusMessage = contentDeletionError != null
          ? 'Saved-page entry removed, but local content could not be deleted: $contentDeletionError'
          : paths.isEmpty
          ? 'Saved-page entry removed. Its content was already missing.'
          : 'Saved page and local content deleted.';
    });
    await _persistAppState();
  }

  Future<void> _deleteAllSavedPages() async {
    final entries = List<SavedPageEntry>.of(_savedPages);
    final paths = <String>{};
    for (final entry in entries) {
      paths.addAll(await SavedPageContentStore.existingPaths(entry));
    }
    if (!mounted ||
        !await _confirmSavedContentDeletion(
          title: 'Delete all saved pages?',
          paths: paths.toList()..sort(),
        )) {
      return;
    }
    final contentDeletionErrors = <Object>[];
    for (final entry in entries) {
      try {
        await SavedPageContentStore.deleteIfPresent(entry);
      } catch (error) {
        contentDeletionErrors.add(error);
      }
    }
    if (!mounted) return;
    final savedPaths = entries.map((entry) => entry.filePath).toSet();
    setState(() {
      _savedPages.clear();
      for (final tab in _tabs) {
        if (savedPaths.contains(tab.savedFilePath)) {
          tab
            ..savedMarkdown = null
            ..savedFilePath = null;
        }
      }
      _statusMessage = contentDeletionErrors.isNotEmpty
          ? 'Saved-page list cleared, but some local content could not be deleted.'
          : paths.isEmpty
          ? 'Saved-page list cleared. Its content was already missing.'
          : 'Saved pages and local content deleted.';
    });
    await _persistAppState();
  }

  Future<void> _saveHomePageSetting() async {
    final input = _homePageController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _statusMessage = 'Enter a home page URL before saving.';
      });
      return;
    }
    setState(() {
      _homePageUrl = _normalizeAddress(input);
      _homePageController.text = _homePageUrl;
      _statusMessage = 'Home page set: $_homePageUrl';
    });
    await _persistAppState();
  }

  Future<void> _clearWebViewData() async {
    final controller = _webViewController;
    if (controller != null) {
      await controller.clearCache();
      await controller.clearLocalStorage();
    }
    await WebViewCookieManager().clearCookies();
  }

  Future<void> _showDataControlsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Data controls'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Markdown, images, bookmarks, history, and shared settings are stored in the selected workspace. Cloud synchronization can be provided by the folder location.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _homePageController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Home page',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveHomePageSetting(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Clearing WebView data removes cookies, cache, and local storage. You may need to sign in again to web services.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                _saveHomePageSetting();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Save home'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _localizeImagesInMarkdownFile();
              },
              icon: const Icon(Icons.perm_media_outlined),
              label: const Text('Localize Markdown images'),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _history.clear();
                  _statusMessage = 'History cleared.';
                });
                _persistAppState();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.history_toggle_off),
              label: const Text('Clear history'),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _bookmarks.clear();
                  _statusMessage = 'Bookmarks cleared.';
                });
                _persistAppState();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.bookmark_remove_outlined),
              label: const Text('Clear bookmarks'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteAllSavedPages();
              },
              icon: const Icon(Icons.playlist_remove),
              label: const Text('Delete saved pages'),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _localSaveDirectory = null;
                  _workspace = null;
                  _workspaceRoot = null;
                  _statusMessage = 'Workspace setting cleared.';
                });
                WorkspaceAccess.forget();
                _persistAppState();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.folder_delete_outlined),
              label: const Text('Forget workspace'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await _clearWebViewData();
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                setState(() {
                  _statusMessage = 'WebView cookies and cache cleared.';
                });
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear WebView data'),
            ),
          ],
        );
      },
    );
  }

  PageDocument _convertHtml(String url, String rawHtml) {
    final parsed = html_parser.parse(rawHtml);
    _removeNoisyElements(parsed);
    final metadata = _extractMetadata(parsed, url);
    final contentRoot = _contentRoot(parsed);
    final markdown = _nodeToMarkdown(contentRoot).trim();
    final outline = contentRoot
        .querySelectorAll('h1,h2,h3,h4,h5,h6')
        .map((node) => node.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final links = contentRoot
        .querySelectorAll('a[href]')
        .map((node) => node.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .toSet()
        .toList();
    final images = contentRoot
        .querySelectorAll('img[src]')
        .map((node) => node.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .toSet()
        .toList();
    final warnings = <String>[
      if (markdown.isEmpty) 'No readable Markdown content was extracted.',
      if (url.startsWith('http'))
        'HTML was extracted from the native WebView after page load.',
    ];

    return PageDocument(
      url: url,
      rawHtml: rawHtml,
      extractedText: contentRoot.text.trim(),
      markdown: markdown.isEmpty
          ? '# ${metadata.title}\n\n${contentRoot.text.trim()}'
          : markdown,
      metadata: metadata,
      outline: outline,
      links: links,
      images: images,
      warnings: warnings,
    );
  }

  void _removeNoisyElements(dom.Document document) {
    for (final selector in <String>[
      'script',
      'style',
      'noscript',
      'svg',
      'iframe',
      'nav',
      'footer',
      'aside',
      'form',
      '[role="navigation"]',
      '[aria-hidden="true"]',
    ]) {
      document.querySelectorAll(selector).forEach((node) => node.remove());
    }
  }

  PageMetadata _extractMetadata(dom.Document document, String url) {
    String meta(String selector, String attribute) {
      return document.querySelector(selector)?.attributes[attribute]?.trim() ??
          '';
    }

    final title =
        document.querySelector('title')?.text.trim().isNotEmpty == true
        ? document.querySelector('title')!.text.trim()
        : document.querySelector('h1')?.text.trim() ?? 'Untitled page';

    return PageMetadata(
      title: title,
      description: meta('meta[name="description"]', 'content').isNotEmpty
          ? meta('meta[name="description"]', 'content')
          : meta('meta[property="og:description"]', 'content'),
      author: meta('meta[name="author"]', 'content'),
      published: meta('meta[property="article:published_time"]', 'content'),
      sourceUrl: url,
      siteName: meta('meta[property="og:site_name"]', 'content'),
    );
  }

  dom.Element _contentRoot(dom.Document document) {
    return document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body ??
        document.documentElement!;
  }

  String _nodeToMarkdown(dom.Node node) {
    if (node is dom.Text) {
      return node.text.replaceAll(RegExp(r'\s+'), ' ');
    }
    if (node is! dom.Element) {
      return node.nodes.map(_nodeToMarkdown).join();
    }

    final tag = node.localName?.toLowerCase();
    final children = node.nodes.map(_nodeToMarkdown).join().trim();

    switch (tag) {
      case 'h1':
        return '\n# $children\n\n';
      case 'h2':
        return '\n## $children\n\n';
      case 'h3':
        return '\n### $children\n\n';
      case 'h4':
        return '\n#### $children\n\n';
      case 'h5':
        return '\n##### $children\n\n';
      case 'h6':
        return '\n###### $children\n\n';
      case 'p':
        return children.isEmpty ? '' : '$children\n\n';
      case 'strong':
      case 'b':
        return '**$children**';
      case 'em':
      case 'i':
        return '*$children*';
      case 'blockquote':
        return children
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => '> ${line.trim()}')
            .join('\n')
            .replaceFirst(RegExp(r'$'), '\n\n');
      case 'pre':
        return '\n```\n${node.text.trim()}\n```\n\n';
      case 'code':
        return '`${node.text.trim()}`';
      case 'a':
        final href = node.attributes['href'] ?? '';
        final label = node.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .replaceAll('[', r'\[')
            .replaceAll(']', r'\]');
        return href.isEmpty ? label : '[$label]($href)';
      case 'img':
        final src = node.attributes['src'] ?? '';
        final alt = node.attributes['alt'] ?? 'image';
        return src.isEmpty ? '' : '![${alt.trim()}]($src)\n\n';
      case 'ul':
        return '${_listItems(node, ordered: false)}\n';
      case 'ol':
        return '${_listItems(node, ordered: true)}\n';
      case 'li':
        return children;
      case 'br':
        return '\n';
      case 'table':
        return '\n${_tableToMarkdown(node)}\n\n';
      default:
        return children.isEmpty ? '' : '$children ';
    }
  }

  String _listItems(dom.Element list, {required bool ordered}) {
    final items = list.children
        .where((child) => child.localName == 'li')
        .toList();
    return items
        .asMap()
        .entries
        .map((entry) {
          final prefix = ordered ? '${entry.key + 1}. ' : '- ';
          return '$prefix${_nodeToMarkdown(entry.value).trim()}';
        })
        .join('\n');
  }

  String _tableToMarkdown(dom.Element table) {
    final rows = table
        .querySelectorAll('tr')
        .map((row) {
          return row.children
              .where((cell) => cell.localName == 'th' || cell.localName == 'td')
              .map((cell) => cell.text.trim().replaceAll('|', r'\|'))
              .toList();
        })
        .where((row) => row.isNotEmpty)
        .toList();
    if (rows.isEmpty) {
      return '';
    }
    final width = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    final header = rows.first;
    final normalizedHeader = List<String>.generate(
      width,
      (index) => index < header.length ? header[index] : '',
    );
    final separator = List<String>.filled(width, '---');
    final body = rows.skip(1).map((row) {
      final normalized = List<String>.generate(
        width,
        (index) => index < row.length ? row[index] : '',
      );
      return '| ${normalized.join(' | ')} |';
    });
    return <String>[
      '| ${normalizedHeader.join(' | ')} |',
      '| ${separator.join(' | ')} |',
      ...body,
    ].join('\n');
  }

  String _normalizeAddress(String input) {
    if (input.startsWith('http://') ||
        input.startsWith('https://') ||
        input.startsWith('local://')) {
      return input;
    }
    if (input.contains('.') && !input.contains(' ')) {
      return 'https://$input';
    }
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(input)}';
  }

  @override
  Widget build(BuildContext context) {
    final document = _activeTab.document;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TabStrip(
              tabs: _tabs,
              activeIndex: _activeIndex,
              onSelect: _selectTab,
              onClose: _closeTab,
              onNewTab: _newTab,
            ),
            _Toolbar(
              addressController: _addressController,
              activeTab: _activeTab,
              canGoBack: _canGoBack,
              canGoForward: _canGoForward,
              isLoading: _isLoading,
              isSavingLocal: _isSavingLocal,
              saveAllLocally: _saveAllLocally,
              showLibraryRail: _showLibraryRail,
              showInsightPanel: _showInsightPanel,
              localSaveDirectory: _workspaceRoot,
              isCurrentPageSaved:
                  document != null &&
                  _savedPages.any(
                    (page) =>
                        page.url == document.url &&
                        (!_saveAllLocally || page.allLocal) &&
                        (page.contentHash ==
                                _contentHash(
                                  _markdownController.text.isEmpty
                                      ? document.markdown
                                      : _markdownController.text,
                                ) ||
                            page.localizedContentHash ==
                                _contentHash(
                                  _markdownController.text.isEmpty
                                      ? document.markdown
                                      : _markdownController.text,
                                )),
                  ),
              onOpen: _openAddress,
              onHome: () => _openHomePage(),
              onBack: _goBack,
              onForward: _goForward,
              onReload: _openAddress,
              onSave: _saveCurrentPage,
              onChooseFolder: _chooseLocalFolder,
              onBookmark: _bookmarkCurrentPage,
              onDataControls: _showDataControlsDialog,
              onToggleLibrary: () {
                setState(() {
                  _showLibraryRail = !_showLibraryRail;
                });
              },
              onToggleInsights: () {
                setState(() {
                  _showInsightPanel = !_showInsightPanel;
                });
              },
              onToggleSaveAllLocally: (value) {
                setState(() {
                  _saveAllLocally = value;
                });
                _persistAppState();
              },
            ),
            Expanded(
              child: _buildWorkspaceBody(
                document: document,
                width: MediaQuery.sizeOf(context).width,
              ),
            ),
            if (_statusMessage != null)
              _StatusBar(message: _statusMessage!, isLoading: _isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody({
    required PageDocument? document,
    required double width,
  }) {
    final content = Column(
      children: [
        _ModeSelector(
          activeMode: _activeTab.viewMode,
          onSelected: _setViewMode,
        ),
        Expanded(child: _mainView(document: document)),
      ],
    );
    if (width < 900) {
      if (!_showLibraryRail) return content;
      return Row(
        children: [
          SizedBox(width: width < 600 ? 220 : 250, child: _buildLibraryRail()),
          Expanded(child: content),
        ],
      );
    }
    return Row(
      children: [
        if (_showLibraryRail) SizedBox(width: 250, child: _buildLibraryRail()),
        Expanded(flex: 7, child: content),
        if (_showInsightPanel)
          SizedBox(width: 310, child: _InsightPanel(document: document)),
      ],
    );
  }

  Widget _buildLibraryRail() {
    return _LibraryRail(
      activeSection: _activeLibrarySection,
      history: _history,
      bookmarks: _bookmarks,
      savedPages: _savedPages,
      onSectionChanged: (section) {
        setState(() {
          _activeLibrarySection = section;
        });
      },
      onAddBookmark: _bookmarkCurrentPage,
      onEditBookmark: _editBookmark,
      onDeleteBookmark: _deleteBookmark,
      onDeleteHistory: _deleteHistoryEntry,
      onDeleteSaved: _deleteSavedPage,
      onOpenHistory: (entry) {
        _addressController.text = entry.url;
        _openAddress();
      },
      onOpenBookmark: (bookmark) {
        _addressController.text = bookmark.url;
        _openAddress();
      },
      onOpenSaved: _openSavedPage,
    );
  }

  static String _contentHash(String markdown) {
    final normalized = markdown
        .replaceAll('\r\n', '\n')
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
          (match) => '![${match.group(1)}](<image>)',
        )
        .trim();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Widget _mainView({required PageDocument? document}) {
    if (document == null) {
      return _HtmlPastePanel(
        controller: _htmlController,
        onConvert: _convertPastedHtml,
      );
    }
    switch (_activeTab.viewMode) {
      case ViewMode.web:
        return _NativeWebView(
          document: document,
          controller: _webViewController,
          htmlController: _htmlController,
          onConvert: _convertPastedHtml,
        );
      case ViewMode.reader:
        return _ReaderView(document: document);
      case ViewMode.markdown:
        final savedFilePath = _activeTab.savedFilePath;
        final imageDirectory = savedFilePath == null
            ? null
            : File(savedFilePath).parent.uri.toString();
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xffe9f3ee),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                savedFilePath == null
                    ? 'Markdown converted from the current Web page'
                    : 'Saved Markdown: $savedFilePath',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(
              child: Markdown(
                data: _activeTab.displayedMarkdown,
                imageDirectory: imageDirectory,
                selectable: true,
                padding: const EdgeInsets.all(28),
              ),
            ),
          ],
        );
      case ViewMode.editor:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _markdownController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Markdown editor',
              alignLabelWithHint: true,
            ),
          ),
        );
      case ViewMode.source:
        return _SourceView(document: document);
    }
  }
}

class LocalMarkdownSaver {
  static Future<LocalMarkdownSaveResult> save({
    required String directoryPath,
    required PageDocument document,
    required String markdown,
    required bool saveAllLocally,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = _fileName(document);
    final assetDirectoryName = fileName.replaceAll(RegExp(r'\.md$'), '_assets');
    final assetDirectory = Directory('${directory.path}/$assetDirectoryName');
    final rewrittenMarkdown = saveAllLocally
        ? await _localizeImages(
            markdown: markdown,
            documentUrl: document.url,
            assetDirectory: assetDirectory,
            assetDirectoryName: assetDirectoryName,
          )
        : markdown;

    final output = File('${directory.path}/$fileName');
    await output.writeAsString(
      _markdownWithFrontMatter(document, rewrittenMarkdown),
    );
    return LocalMarkdownSaveResult(
      filePath: output.path,
      markdown: rewrittenMarkdown,
      localizedCount: saveAllLocally
          ? _countLocalizedImageLinks(rewrittenMarkdown, assetDirectoryName)
          : 0,
    );
  }

  static Future<MarkdownImageLocalizationResult> localizeMarkdownFileImages({
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Markdown file does not exist.', filePath);
    }

    final markdown = await file.readAsString();
    final fileName = file.uri.pathSegments.isEmpty
        ? 'markdown'
        : file.uri.pathSegments.last;
    final baseName = fileName.replaceFirst(RegExp(r'\.(md|markdown)$'), '');
    final assetDirectoryName = '${_safeAssetDirectoryName(baseName)}_assets';
    final assetDirectory = Directory('${file.parent.path}/$assetDirectoryName');
    final result = await _localizeImagesWithResult(
      markdown: markdown,
      documentUrl: file.uri.toString(),
      assetDirectory: assetDirectory,
      assetDirectoryName: assetDirectoryName,
      copyLocalFiles: true,
    );

    if (result.localizedCount > 0 && result.markdown != markdown) {
      await file.writeAsString(result.markdown);
    }

    return MarkdownImageLocalizationResult(
      filePath: file.path,
      fileName: fileName,
      markdown: result.markdown,
      imageLinkCount: result.imageLinkCount,
      localizedCount: result.localizedCount,
    );
  }

  static int _countLocalizedImageLinks(
    String markdown,
    String assetDirectoryName,
  ) {
    return RegExp(
      r'!\[[^\]]*\]\(' + RegExp.escape('$assetDirectoryName/') + r'[^)]+\)',
    ).allMatches(markdown).length;
  }

  static Future<String> _localizeImages({
    required String markdown,
    required String documentUrl,
    required Directory assetDirectory,
    required String assetDirectoryName,
    bool copyLocalFiles = false,
  }) async {
    final result = await _localizeImagesWithResult(
      markdown: markdown,
      documentUrl: documentUrl,
      assetDirectory: assetDirectory,
      assetDirectoryName: assetDirectoryName,
      copyLocalFiles: copyLocalFiles,
    );
    return result.markdown;
  }

  static Future<_LocalizedMarkdown> _localizeImagesWithResult({
    required String markdown,
    required String documentUrl,
    required Directory assetDirectory,
    required String assetDirectoryName,
    required bool copyLocalFiles,
  }) async {
    final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    final matches = imagePattern.allMatches(markdown).toList();
    final rewritten = StringBuffer();
    var previousEnd = 0;
    var index = 1;
    var localizedCount = 0;

    for (final match in matches) {
      final original = match.group(0)!;
      var replacement = original;
      final alt = match.group(1) ?? 'image';
      final src = _cleanMarkdownImageDestination(match.group(2) ?? '');
      final uri = _resolveImageUri(documentUrl, src);
      if (uri != null) {
        try {
          final bytes = await _imageBytes(uri, copyLocalFiles: copyLocalFiles);
          if (bytes != null) {
            if (!await assetDirectory.exists()) {
              await assetDirectory.create(recursive: true);
            }
            final extension = _imageExtension(uri, bytes.contentType);
            final assetName =
                'image_${index.toString().padLeft(3, '0')}.$extension';
            final assetFile = File('${assetDirectory.path}/$assetName');
            await assetFile.writeAsBytes(bytes.data);
            replacement = '![${alt.trim()}]($assetDirectoryName/$assetName)';
            index += 1;
            localizedCount += 1;
          }
        } catch (_) {
          replacement = original;
        }
      }
      rewritten
        ..write(markdown.substring(previousEnd, match.start))
        ..write(replacement);
      previousEnd = match.end;
    }
    rewritten.write(markdown.substring(previousEnd));

    return _LocalizedMarkdown(
      markdown: rewritten.toString(),
      imageLinkCount: matches.length,
      localizedCount: localizedCount,
    );
  }

  static Uri? _resolveImageUri(String documentUrl, String src) {
    final parsed = Uri.tryParse(src);
    if (parsed == null) {
      return null;
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    final base = Uri.tryParse(documentUrl);
    if (base == null || !base.hasScheme) {
      return null;
    }
    return base.resolveUri(parsed);
  }

  static Future<_ImageBytes?> _imageBytes(
    Uri uri, {
    required bool copyLocalFiles,
  }) async {
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _ImageBytes(
        data: response.bodyBytes,
        contentType: response.headers['content-type'],
      );
    }
    if (!copyLocalFiles || (uri.scheme.isNotEmpty && uri.scheme != 'file')) {
      return null;
    }
    final file = uri.scheme == 'file' ? File.fromUri(uri) : File(uri.path);
    if (!await file.exists()) {
      return null;
    }
    return _ImageBytes(data: await file.readAsBytes());
  }

  static String _cleanMarkdownImageDestination(String raw) {
    var src = raw.trim();
    if (src.startsWith('<') && src.endsWith('>')) {
      src = src.substring(1, src.length - 1).trim();
    }
    return src;
  }

  static String _imageExtension(Uri uri, String? contentType) {
    final pathExtension = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last.split('.').last.toLowerCase();
    if (<String>{
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'svg',
    }.contains(pathExtension)) {
      return pathExtension == 'jpeg' ? 'jpg' : pathExtension;
    }
    if (contentType?.contains('png') == true) return 'png';
    if (contentType?.contains('gif') == true) return 'gif';
    if (contentType?.contains('webp') == true) return 'webp';
    if (contentType?.contains('svg') == true) return 'svg';
    return 'jpg';
  }

  static String _safeAssetDirectoryName(String value) {
    final safeName = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safeName.isEmpty ? 'markdown' : safeName;
  }

  static String _fileName(PageDocument document) {
    final title = document.metadata.title.trim().isEmpty
        ? 'Untitled page'
        : document.metadata.title.trim();
    final safeTitle = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '-');
    return '$safeTitle-$timestamp.md';
  }

  static String _markdownWithFrontMatter(
    PageDocument document,
    String markdown,
  ) {
    final metadata = document.metadata;
    final escapedTitle = metadata.title.replaceAll('"', r'\"');
    return '''
---
title: "$escapedTitle"
source: "${metadata.sourceUrl}"
site: "${metadata.siteName}"
author: "${metadata.author}"
published: "${metadata.published}"
created: "${DateTime.now().toUtc().toIso8601String()}"
---

$markdown
''';
  }
}

class MarkdownImageLocalizationResult {
  const MarkdownImageLocalizationResult({
    required this.filePath,
    required this.fileName,
    required this.markdown,
    required this.imageLinkCount,
    required this.localizedCount,
  });

  final String filePath;
  final String fileName;
  final String markdown;
  final int imageLinkCount;
  final int localizedCount;
}

class LocalMarkdownSaveResult {
  const LocalMarkdownSaveResult({
    required this.filePath,
    required this.markdown,
    required this.localizedCount,
  });

  final String filePath;
  final String markdown;
  final int localizedCount;
}

class _LocalizedMarkdown {
  const _LocalizedMarkdown({
    required this.markdown,
    required this.imageLinkCount,
    required this.localizedCount,
  });

  final String markdown;
  final int imageLinkCount;
  final int localizedCount;
}

class _ImageBytes {
  const _ImageBytes({required this.data, this.contentType});

  final List<int> data;
  final String? contentType;
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
    required this.onNewTab,
  });

  final List<BrowserTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xffe6eceb),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final selected = index == activeIndex;
                return Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Material(
                    color: selected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.white,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xffcfd8d7),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelect(index),
                      child: SizedBox(
                        height: 32,
                        width: 220,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tabs[index].title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close tab',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 30,
                                height: 30,
                              ),
                              onPressed: () => onClose(index),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'New tab',
            onPressed: onNewTab,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.addressController,
    required this.activeTab,
    required this.canGoBack,
    required this.canGoForward,
    required this.isLoading,
    required this.isSavingLocal,
    required this.saveAllLocally,
    required this.showLibraryRail,
    required this.showInsightPanel,
    required this.localSaveDirectory,
    required this.isCurrentPageSaved,
    required this.onOpen,
    required this.onHome,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onSave,
    required this.onChooseFolder,
    required this.onBookmark,
    required this.onDataControls,
    required this.onToggleLibrary,
    required this.onToggleInsights,
    required this.onToggleSaveAllLocally,
  });

  final TextEditingController addressController;
  final BrowserTab activeTab;
  final bool canGoBack;
  final bool canGoForward;
  final bool isLoading;
  final bool isSavingLocal;
  final bool saveAllLocally;
  final bool showLibraryRail;
  final bool showInsightPanel;
  final String? localSaveDirectory;
  final bool isCurrentPageSaved;
  final VoidCallback onOpen;
  final VoidCallback onHome;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onSave;
  final VoidCallback onChooseFolder;
  final VoidCallback onBookmark;
  final VoidCallback onDataControls;
  final VoidCallback onToggleLibrary;
  final VoidCallback onToggleInsights;
  final ValueChanged<bool> onToggleSaveAllLocally;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Material(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: canGoBack ? onBack : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'Forward',
              onPressed: canGoForward ? onForward : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              tooltip: 'Reload',
              onPressed: isLoading ? null : onReload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Home',
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined),
            ),
            Expanded(
              child: TextField(
                controller: addressController,
                onSubmitted: (_) => onOpen(),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.travel_explore),
                  hintText: 'Enter URL or search terms',
                  suffixIcon: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Open',
                          onPressed: onOpen,
                          icon: const Icon(Icons.arrow_circle_right_outlined),
                        ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: localSaveDirectory == null
                  ? 'Choose workspace'
                  : 'Workspace: $localSaveDirectory',
              child: IconButton(
                onPressed: onChooseFolder,
                icon: const Icon(Icons.folder_open),
              ),
            ),
            Tooltip(
              message:
                  'Save available images beside the Markdown file and use relative links',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: saveAllLocally,
                    onChanged: (value) =>
                        onToggleSaveAllLocally(value ?? false),
                  ),
                  if (!compact) const Text('Local images'),
                ],
              ),
            ),
            Tooltip(
              message: showLibraryRail ? 'Hide bookmarks' : 'Show bookmarks',
              child: IconButton(
                onPressed: onToggleLibrary,
                icon: Icon(showLibraryRail ? Icons.menu_open : Icons.menu),
              ),
            ),
            Tooltip(
              message: 'Bookmark current page',
              child: IconButton(
                onPressed: activeTab.currentUrl.isEmpty ? null : onBookmark,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            ),
            Tooltip(
              message: 'Clear history, bookmarks, or WebView data',
              child: IconButton(
                onPressed: onDataControls,
                icon: const Icon(Icons.cleaning_services_outlined),
              ),
            ),
            Tooltip(
              message: showInsightPanel ? 'Hide metadata' : 'Show metadata',
              child: IconButton(
                onPressed: onToggleInsights,
                icon: Icon(
                  showInsightPanel
                      ? Icons.close_fullscreen
                      : Icons.info_outline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed:
                  activeTab.document == null ||
                      isSavingLocal ||
                      isCurrentPageSaved
                  ? null
                  : onSave,
              icon: isSavingLocal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isCurrentPageSaved ? Icons.check_circle : Icons.save_alt,
                    ),
              label: Text(isCurrentPageSaved ? 'Saved' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.activeMode, required this.onSelected});

  final ViewMode activeMode;
  final ValueChanged<ViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      alignment: Alignment.centerLeft,
      child: SegmentedButton<ViewMode>(
        segments: ViewMode.values.map((mode) {
          return ButtonSegment<ViewMode>(
            value: mode,
            icon: Icon(mode.icon),
            label: Text(mode.label),
          );
        }).toList(),
        selected: {activeMode},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }
}

class _LibraryRail extends StatefulWidget {
  const _LibraryRail({
    required this.activeSection,
    required this.history,
    required this.bookmarks,
    required this.savedPages,
    required this.onSectionChanged,
    required this.onAddBookmark,
    required this.onEditBookmark,
    required this.onDeleteBookmark,
    required this.onDeleteHistory,
    required this.onDeleteSaved,
    required this.onOpenHistory,
    required this.onOpenBookmark,
    required this.onOpenSaved,
  });

  final LibrarySection activeSection;
  final List<PageLinkEntry> history;
  final List<PageLinkEntry> bookmarks;
  final List<SavedPageEntry> savedPages;
  final ValueChanged<LibrarySection> onSectionChanged;
  final VoidCallback onAddBookmark;
  final ValueChanged<PageLinkEntry> onEditBookmark;
  final ValueChanged<PageLinkEntry> onDeleteBookmark;
  final ValueChanged<PageLinkEntry> onDeleteHistory;
  final ValueChanged<SavedPageEntry> onDeleteSaved;
  final ValueChanged<PageLinkEntry> onOpenHistory;
  final ValueChanged<PageLinkEntry> onOpenBookmark;
  final ValueChanged<SavedPageEntry> onOpenSaved;

  @override
  State<_LibraryRail> createState() => _LibraryRailState();
}

class _LibraryRailState extends State<_LibraryRail> {
  late LibrarySection _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.activeSection;
  }

  @override
  void didUpdateWidget(covariant _LibraryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeSection != oldWidget.activeSection &&
        widget.activeSection != _selectedSection) {
      _selectedSection = widget.activeSection;
    }
  }

  void _selectSection(LibrarySection section) {
    if (_selectedSection == section) return;
    setState(() {
      _selectedSection = section;
    });
    widget.onSectionChanged(section);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xffedf2f1),
      shape: const Border(right: BorderSide(color: Color(0xffd8e0df))),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<LibrarySection>(
            showSelectedIcon: false,
            segments: LibrarySection.values.map((section) {
              return ButtonSegment<LibrarySection>(
                value: section,
                tooltip: section.label,
                icon: Icon(section.icon, size: 18),
              );
            }).toList(),
            selected: {_selectedSection},
            onSelectionChanged: (selection) => _selectSection(selection.first),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedSection.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_selectedSection == LibrarySection.bookmarks)
                IconButton(
                  tooltip: 'Bookmark current page',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onAddBookmark,
                  icon: const Icon(Icons.add, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ..._sectionItems(),
        ],
      ),
    );
  }

  List<Widget> _sectionItems() {
    switch (_selectedSection) {
      case LibrarySection.bookmarks:
        if (widget.bookmarks.isEmpty) {
          return const <Widget>[Text('Use the bookmark button to keep pages.')];
        }
        return widget.bookmarks
            .map(
              (bookmark) => _PageLinkTile(
                entry: bookmark,
                icon: Icons.bookmark_border,
                onTap: () => widget.onOpenBookmark(bookmark),
                onEdit: () => widget.onEditBookmark(bookmark),
                onDelete: () => widget.onDeleteBookmark(bookmark),
              ),
            )
            .toList();
      case LibrarySection.history:
        if (widget.history.isEmpty) {
          return const <Widget>[Text('Open a URL to start history.')];
        }
        return widget.history
            .map(
              (entry) => _PageLinkTile(
                entry: entry,
                icon: Icons.history,
                onTap: () => widget.onOpenHistory(entry),
                onDelete: () => widget.onDeleteHistory(entry),
              ),
            )
            .toList();
      case LibrarySection.saved:
        if (widget.savedPages.isEmpty) {
          return const <Widget>[Text('Saved pages will appear here.')];
        }
        return widget.savedPages
            .map(
              (page) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, size: 18),
                title: Text(
                  page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  page.filePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Saved page actions',
                  onSelected: (value) {
                    if (value == 'delete') widget.onDeleteSaved(page);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => widget.onOpenSaved(page),
              ),
            )
            .toList();
    }
  }
}

class _PageLinkTile extends StatelessWidget {
  const _PageLinkTile({
    required this.entry,
    required this.icon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final PageLinkEntry entry;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasTitle = entry.title.trim().isNotEmpty;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18),
      title: Text(
        entry.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: hasTitle
          ? Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: onEdit == null && onDelete == null
          ? null
          : PopupMenuButton<String>(
              tooltip: onEdit == null ? 'History actions' : 'Bookmark actions',
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit title')),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
      onTap: onTap,
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.document});

  final PageDocument? document;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfff8fbfa),
      shape: const Border(left: BorderSide(color: Color(0xffd8e0df))),
      child: document == null
          ? const Center(child: Text('No page loaded.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Metadata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _KeyValue(label: 'Title', value: document!.metadata.title),
                _KeyValue(label: 'Source', value: document!.metadata.sourceUrl),
                _KeyValue(
                  label: 'Description',
                  value: document!.metadata.description,
                ),
                _KeyValue(label: 'Author', value: document!.metadata.author),
                _KeyValue(
                  label: 'Published',
                  value: document!.metadata.published,
                ),
                const Divider(height: 28),
                Text('Outline', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (document!.outline.isEmpty)
                  const Text('No headings found.')
                else
                  ...document!.outline.map(
                    (heading) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tag, size: 16),
                      title: Text(heading),
                    ),
                  ),
                const Divider(height: 28),
                Text('Links', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (document!.links.isEmpty)
                  const Text('No links found.')
                else
                  ...document!.links
                      .take(12)
                      .map(
                        (link) => Text(link, overflow: TextOverflow.ellipsis),
                      ),
                const Divider(height: 28),
                Text(
                  'Warnings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...document!.warnings.map((warning) => Text('• $warning')),
              ],
            ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value),
        ],
      ),
    );
  }
}

class _NativeWebView extends StatelessWidget {
  const _NativeWebView({
    required this.document,
    required this.controller,
    required this.htmlController,
    required this.onConvert,
  });

  final PageDocument document;
  final WebViewController? controller;
  final TextEditingController htmlController;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Native WebView',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Native WebView is disabled in this environment. Paste HTML to exercise Reader and Markdown conversion.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _ReaderCard(document: document),
          const SizedBox(height: 24),
          _HtmlPastePanel(controller: htmlController, onConvert: onConvert),
        ],
      );
    }

    return WebViewWidget(controller: controller!);
  }
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({required this.document});

  final PageDocument document;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [_ReaderCard(document: document)],
    );
  }
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({required this.document});

  final PageDocument document;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.metadata.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (document.metadata.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                document.metadata.description,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              document.extractedText,
              style: const TextStyle(fontSize: 17, height: 1.65),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceView extends StatelessWidget {
  const _SourceView({required this.document});

  final PageDocument document;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Raw HTML'),
              Tab(text: 'Extracted text'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CodeBlock(text: document.rawHtml),
                _CodeBlock(text: document.extractedText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _HtmlPastePanel extends StatelessWidget {
  const _HtmlPastePanel({required this.controller, required this.onConvert});

  final TextEditingController controller;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paste HTML', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '<article><h1>Title</h1><p>Content...</p></article>',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onConvert,
            icon: const Icon(Icons.transform),
            label: const Text('Convert pasted HTML'),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.message, required this.isLoading});

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: const Color(0xff253635),
      child: Row(
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
