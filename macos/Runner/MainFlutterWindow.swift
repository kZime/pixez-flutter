import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, FlutterStreamHandler {
    private var desktopMenuChannel: FlutterMethodChannel?
    private var desktopFindItem: NSMenuItem?
    private var desktopBackItem: NSMenuItem?

    private func findSearchItem(in menu: NSMenu?) -> NSMenuItem? {
        for item in menu?.items ?? [] {
            if item.tag == 1 && item.keyEquivalent == "f" {
                return item
            }
            if let found = findSearchItem(in: item.submenu) { return found }
        }
        return nil
    }

    @objc private func searchDesktop(_ sender: Any?) {
        desktopMenuChannel?.invokeMethod("search", arguments: nil)
    }

    @objc private func goBackDesktop(_ sender: Any?) {
        desktopMenuChannel?.invokeMethod("back", arguments: nil)
    }

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        let uniLinksChannel = FlutterMethodChannel(
            name: "deep_links/messages",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        uniLinksChannel.setMethodCallHandler { call, result in
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            if call.method == "getInitialLink" {
                result(appDelegate.initialLink)
                appDelegate.initialLink = nil
            } else if call.method == "getLatestLink" {
                result(appDelegate.latestLink)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        let eventChannel = FlutterEventChannel(name: "deep_links/events", binaryMessenger: flutterViewController.engine.binaryMessenger)
        eventChannel.setStreamHandler(self)

        // The native Find menu consumes Cmd+F before Flutter's key handlers.
        // Redirect it only while the opt-in desktop surface is mounted.
        let menuChannel = FlutterMethodChannel(
            name: "pixez/desktop_menu",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        desktopMenuChannel = menuChannel
        menuChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "enable":
                self.desktopFindItem = self.findSearchItem(in: NSApp.mainMenu)
                self.desktopFindItem?.target = self
                self.desktopFindItem?.action = #selector(self.searchDesktop(_:))
                if self.desktopBackItem == nil,
                   let viewMenu = NSApp.mainMenu?.items.first(where: {
                       $0.submenu?.items.contains(where: {
                           $0.action == #selector(NSWindow.toggleFullScreen(_:))
                       }) == true
                   })?.submenu {
                    let back = NSMenuItem(title: "Back", action: #selector(self.goBackDesktop(_:)), keyEquivalent: "[")
                    back.keyEquivalentModifierMask = [.command]
                    back.target = self
                    viewMenu.insertItem(back, at: 0)
                    self.desktopBackItem = back
                }
                result(nil)
            case "disable":
                self.desktopFindItem?.target = nil
                self.desktopFindItem?.action = Selector(("performFindPanelAction:"))
                self.desktopFindItem = nil
                if let back = self.desktopBackItem { back.menu?.removeItem(back) }
                self.desktopBackItem = nil
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        DocumentPlugin.bind(controller: flutterViewController)

        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.eventSink = events
        DispatchQueue.main.async {
            if let link = appDelegate.initialLink, let sink = appDelegate.eventSink {
                appDelegate.initialLink = nil
                sink(link)
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.eventSink = nil
        return nil
    }
}
