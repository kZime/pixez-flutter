import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var eventSink: FlutterEventSink?
    var initialLink: String?
    var latestLink: String?

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func application(_ application: NSApplication, open urls: [URL]) {
        for i in urls {
            latestLink = i.absoluteString
            if let sink = eventSink {
                sink(i.absoluteString)
            } else {
                initialLink = i.absoluteString
            }
        }
    }
}
