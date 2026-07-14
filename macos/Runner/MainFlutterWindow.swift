import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let workspaceChannel = FlutterMethodChannel(
      name: "markdown_browser/workspace",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    workspaceChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "chooseWorkspace":
        let panel = NSOpenPanel()
        panel.title = "Choose Markdown Browser Workspace"
        panel.prompt = "Use Workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
          result(nil)
          return
        }
        do {
          let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          UserDefaults.standard.set(data, forKey: "MarkdownBrowserWorkspaceBookmark")
          _ = url.startAccessingSecurityScopedResource()
          result(url.path)
        } catch {
          result(FlutterError(code: "bookmark_failed", message: error.localizedDescription, details: nil))
        }
      case "saveBookmark":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(FlutterError(code: "invalid_path", message: "A workspace path is required.", details: nil))
          return
        }
        do {
          let url = URL(fileURLWithPath: path, isDirectory: true)
          let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          UserDefaults.standard.set(data, forKey: "MarkdownBrowserWorkspaceBookmark")
          _ = url.startAccessingSecurityScopedResource()
          result(path)
        } catch {
          result(FlutterError(code: "bookmark_failed", message: error.localizedDescription, details: nil))
        }
      case "resolveBookmark":
        guard let data = UserDefaults.standard.data(forKey: "MarkdownBrowserWorkspaceBookmark") else {
          result(nil)
          return
        }
        do {
          var stale = false
          let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
          )
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "access_denied", message: "Workspace access could not be restored.", details: nil))
            return
          }
          if stale {
            let refreshed = try url.bookmarkData(
              options: [.withSecurityScope],
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )
            UserDefaults.standard.set(refreshed, forKey: "MarkdownBrowserWorkspaceBookmark")
          }
          result(url.path)
        } catch {
          result(FlutterError(code: "resolve_failed", message: error.localizedDescription, details: nil))
        }
      case "clearBookmark":
        UserDefaults.standard.removeObject(forKey: "MarkdownBrowserWorkspaceBookmark")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
