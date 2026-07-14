import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_browser/main.dart';

void main() {
  testWidgets('renders the native Markdown browser shell', (tester) async {
    await tester.pumpWidget(
      const MarkdownBrowserApp(enableNativeWebView: false),
    );

    expect(find.text('Web'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('library sections remain selectable in compact layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MarkdownBrowserApp(enableNativeWebView: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('History'));
    await tester.pump();
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.byTooltip('Saved'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saved pages will appear here.'), findsOneWidget);
  });

  test('localizes images and rewrites the selected Markdown file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'markdown-browser-test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final sourceImage = File('${directory.path}/source image.png');
    await sourceImage.writeAsBytes(<int>[137, 80, 78, 71]);
    final markdownFile = File('${directory.path}/notes.md');
    await markdownFile.writeAsString('Before\n\n![sample](<source image.png>)');

    final result = await LocalMarkdownSaver.localizeMarkdownFileImages(
      filePath: markdownFile.path,
    );

    expect(result.localizedCount, 1);
    expect(result.imageLinkCount, 1);
    expect(result.markdown, contains('![sample](notes_assets/image_001.png)'));
    expect(await markdownFile.readAsString(), result.markdown);
    expect(
      await File('${directory.path}/notes_assets/image_001.png').readAsBytes(),
      <int>[137, 80, 78, 71],
    );
  });

  test('persists saved-page information across app restarts', () {
    final savedAt = DateTime.utc(2026, 7, 13, 12, 30);
    final state = PersistedAppState(
      bookmarks: const <PageLinkEntry>[],
      history: const <PageLinkEntry>[],
      savedPages: <SavedPageEntry>[
        SavedPageEntry(
          url: 'https://example.com/article',
          title: 'Article',
          contentHash: 'content-hash',
          localizedContentHash: 'localized-content-hash',
          filePath: '/notes/article.md',
          savedAt: savedAt,
          allLocal: true,
        ),
      ],
      lastSaveDirectory: '/notes',
      homePageUrl: 'https://example.com',
      saveAllLocally: true,
    );

    final restored = PersistedAppState.fromJson(state.toJson());

    expect(restored.savedPages, hasLength(1));
    expect(restored.savedPages.single.url, 'https://example.com/article');
    expect(restored.savedPages.single.contentHash, 'content-hash');
    expect(
      restored.savedPages.single.localizedContentHash,
      'localized-content-hash',
    );
    expect(restored.savedPages.single.filePath, '/notes/article.md');
    expect(restored.savedPages.single.savedAt, savedAt);
    expect(restored.savedPages.single.allLocal, isTrue);
  });

  test('deletes saved Markdown and its asset directory when present', () async {
    final directory = await Directory.systemTemp.createTemp(
      'markdown-browser-delete-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final markdown = File('${directory.path}/article.md');
    final assets = Directory('${directory.path}/article_assets');
    await markdown.writeAsString('# Saved article');
    await assets.create();
    await File('${assets.path}/image.png').writeAsBytes(<int>[1, 2, 3]);
    final entry = SavedPageEntry(
      url: 'https://example.com/article',
      title: 'Article',
      contentHash: 'hash',
      localizedContentHash: 'localized-hash',
      filePath: markdown.path,
      savedAt: DateTime.utc(2026, 7, 14),
      allLocal: true,
    );

    expect(await SavedPageContentStore.existingPaths(entry), <String>[
      markdown.path,
      assets.path,
    ]);

    await SavedPageContentStore.deleteIfPresent(entry);

    expect(await markdown.exists(), isFalse);
    expect(await assets.exists(), isFalse);
  });

  test(
    'deleting saved content succeeds when its folder is already gone',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'markdown-browser-missing-delete-test-',
      );
      final missingPath = '${directory.path}/missing/article.markdown';
      await directory.delete(recursive: true);
      final entry = SavedPageEntry(
        url: 'https://example.com/missing',
        title: 'Missing',
        contentHash: 'hash',
        localizedContentHash: 'localized-hash',
        filePath: missingPath,
        savedAt: DateTime.utc(2026, 7, 14),
        allLocal: true,
      );

      expect(await SavedPageContentStore.existingPaths(entry), isEmpty);
      await expectLater(
        SavedPageContentStore.deleteIfPresent(entry),
        completes,
      );
    },
  );

  test('creates and reloads a cloud-friendly workspace', () async {
    final directory = await Directory.systemTemp.createTemp(
      'markdown-browser-workspace-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final workspace = await WorkspaceStore.open(directory.path);
    await workspace.save(
      bookmarks: const <PageLinkEntry>[
        PageLinkEntry(url: 'https://example.com', title: 'Example'),
      ],
      history: const <PageLinkEntry>[
        PageLinkEntry(url: 'https://example.com/page', title: 'Page'),
      ],
      homePageUrl: 'https://example.com',
      saveAllLocally: true,
    );

    final restored = await workspace.load();

    expect(await Directory(workspace.articlesPath).exists(), isTrue);
    expect(await Directory(workspace.bookmarksPath).exists(), isTrue);
    expect(await Directory(workspace.historyPath).exists(), isTrue);
    expect(await Directory(workspace.devicesPath).exists(), isTrue);
    expect(restored.bookmarks.single.url, 'https://example.com');
    expect(restored.history.single.url, 'https://example.com/page');
    expect(restored.homePageUrl, 'https://example.com');
    expect(restored.saveAllLocally, isTrue);
  });
}
