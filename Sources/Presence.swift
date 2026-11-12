// mCLOUD — icône de la barre de menus (silhouette monochrome « modèle », s'adapte au thème) et son menu.
// Pas de statusItem.menu : le menu est ouvert sous l'icône à la main (sinon il s'ouvre loin de l'icône avec plusieurs écrans).
import AppKit
import Combine

@MainActor
final class Presence: NSObject {
    static let shared = Presence()
    var openMain: (() -> Void)?
    private var item: NSStatusItem?
    private var bag = Set<AnyCancellable>()

    func install() {
        let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item = it
        it.menu = nil
        it.button?.imagePosition = .imageOnly
        it.button?.target = self
        it.button?.action = #selector(clicked)
        it.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshIcon()
        Veille.shared.objectWillChange.sink { [weak self] in DispatchQueue.main.async { self?.refreshIcon() } }.store(in: &bag)
        Mounter.shared.objectWillChange.sink { [weak self] in DispatchQueue.main.async { self?.refreshIcon() } }.store(in: &bag)
    }

    private func refreshIcon() {
        item?.button?.image = Self.icon(alert: Veille.shared.unread > 0, active: Mounter.shared.anyActive)
        item?.button?.toolTip = "mCLOUD"
    }

    /// Nuage blanc (modèle) ; plein quand un disque est monté, contour sinon ; point en haut à droite quand la veille a un signalement.
    static func icon(alert: Bool, active: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            let cloud = NSBezierPath()
            cloud.appendOval(in: NSRect(x: 2.5, y: 3.5, width: 7, height: 7))
            cloud.appendOval(in: NSRect(x: 6, y: 5.5, width: 8.5, height: 8.5))
            cloud.appendOval(in: NSRect(x: 11, y: 4, width: 6.5, height: 6.5))
            cloud.appendRoundedRect(NSRect(x: 4.5, y: 3.5, width: 11, height: 4), xRadius: 2, yRadius: 2)
            NSColor.black.setFill(); NSColor.black.setStroke()
            if active { cloud.fill() } else { cloud.lineWidth = 1.3; cloud.stroke() }
            if alert { NSBezierPath(ovalIn: NSRect(x: 14.5, y: 11.5, width: 5, height: 5)).fill() }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Menu sous l'icône, placé selon l'écran de l'icône (Socle : `NSStatusItem.socleShow`).
    @objc private func clicked() { item?.socleShow(makeMenu()) }

    private func makeMenu() -> NSMenu {
        let m = NSMenu()
        func add(_ title: String, _ sel: Selector, _ obj: Any? = nil) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: ""); i.target = self; i.representedObject = obj; m.addItem(i)
        }
        let accounts = Store.shared.accounts
        if accounts.isEmpty { let i = NSMenuItem(title: L("menu.none"), action: nil, keyEquivalent: ""); i.isEnabled = false; m.addItem(i) }
        for a in accounts {
            switch Mounter.shared.state(a) {
            case .on: add("\(L("acc.unmount")) \(a.name)", #selector(toggle(_:)), a.id)
            case .starting, .healing: let i = NSMenuItem(title: "\(a.name) — \(L("acc.status.starting"))", action: nil, keyEquivalent: ""); i.isEnabled = false; m.addItem(i)
            default: add("\(L("acc.mount")) \(a.name)", #selector(toggle(_:)), a.id)
            }
        }
        m.addItem(.separator())
        if Veille.shared.unread > 0 { add(L("menu.watch", Veille.shared.unread), #selector(openMainAction)) }
        add(L("menu.open"), #selector(openMainAction))
        add(L("about.menu"), #selector(about))
        add(L("menu.quit"), #selector(quit))
        return m
    }

    @objc private func toggle(_ s: NSMenuItem) {
        guard let id = s.representedObject as? UUID, let a = Store.shared.accounts.first(where: { $0.id == id }) else { return }
        Task { if case .on = Mounter.shared.state(a) { await Mounter.shared.unmount(a) } else { await Mounter.shared.mount(a) } }
    }
    @objc private func openMainAction() { openMain?() }
    @objc private func about() { About.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
