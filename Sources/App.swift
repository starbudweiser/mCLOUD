// mCLOUD — point d'entrée : fenêtre, barre de menus, montage au lancement, veille et mise à jour.
import AppKit
import SwiftUI

@main
struct MCloudMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        Socle.apply(.dark)
        Socle.brand("mCLOUD", color: Color(nsColor: BrandStyle.color))
        Presence.shared.openMain = { [weak self] in self?.showMain() }
        Presence.shared.apply()
        Mounter.shared.startMonitoring()
        Veille.shared.start()
        Updater.shared.start(busy: { Mounter.shared.states.values.contains { $0 == .starting || $0 == .healing } })
        if !CommandLine.arguments.contains("--silent") { showMain() }
        Task { await Mounter.shared.mountAtLaunch() }
    }

    func showMain() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "mCLOUD"
            w.isOpaque = true
            w.backgroundColor = NSColor(Socle.C.bg)
            w.minSize = NSSize(width: 720, height: 460)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: RootView())
            w.setFrameAutosaveName("mCLOUDMain")
            if !w.setFrameUsingName("mCLOUDMain") { w.socleCenter() }
            window = w
        }
        window?.present()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool { showMain(); return true }

    /// Démonte proprement les disques avant de quitter.
    func applicationShouldTerminate(_ s: NSApplication) -> NSApplication.TerminateReply {
        guard Mounter.shared.anyActive else { return .terminateNow }
        Task { await Mounter.shared.unmountAll(); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
