// mCLOUD — interface (design Socle) : comptes, veille, réglages.
import AppKit
import ServiceManagement
import SwiftUI

enum Tab: CaseIterable { case accounts, watch, settings
    var key: String { switch self { case .accounts: "tab.accounts"; case .watch: "tab.watch"; case .settings: "tab.settings" } }
}

struct RootView: View {
    @ObservedObject private var veille = Veille.shared
    @State private var tab: Tab = .accounts

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Socle.M.space2) {
                Text(branded: "mCLOUD").socle(Socle.T.display).foregroundStyle(Socle.C.textStrong)
                Spacer()
                ForEach(Tab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        HStack(spacing: 6) {
                            Text(L(t.key))
                            if t == .watch, veille.unread > 0 { Text("\(veille.unread)").socle(Socle.T.caption).padding(.horizontal, 5).background(Socle.C.warning, in: Capsule()).foregroundStyle(Socle.C.bg) }
                        }
                    }.buttonStyle(SocleButtonStyle(tab == t ? .primary : .secondary))
                }
            }
            .padding(.horizontal, Socle.M.space4).frame(height: Socle.M.sizeBar + 8)
            .background(Socle.C.surfaceRaised)
            Divider().overlay(Socle.C.border)
            Group {
                switch tab {
                case .accounts: AccountsView()
                case .watch: VeilleView()
                case .settings: SettingsView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Socle.C.bg)
    }
}

// MARK: Comptes

struct AccountsView: View {
    @ObservedObject private var store = Store.shared
    @ObservedObject private var mounter = Mounter.shared
    @State private var adding = false
    @State private var editing: Account?
    @State private var authorizing: Account?
    @State private var imported: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            HStack {
                if Importer.available { Button(L("acc.import")) { imported = Importer.run() }.buttonStyle(SocleButtonStyle(.secondary)) }
                if let n = imported { Text(L("acc.import.done", n)).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted) }
                Spacer()
                Button(L("acc.add")) { adding = true }.buttonStyle(SocleButtonStyle(.primary))
            }
            if store.accounts.isEmpty {
                VStack(spacing: Socle.M.space2) {
                    Image(systemName: "cloud").font(.system(size: 40)).foregroundStyle(Socle.C.textSubtle)
                    Text(L("acc.empty.title")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
                    Text(L("acc.empty.body")).socle(Socle.T.body).foregroundStyle(Socle.C.textMuted).multilineTextAlignment(.center).frame(maxWidth: 420)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(spacing: 1) { ForEach(store.accounts) { a in row(a) } } }
                    .background(Socle.C.border)
            }
        }
        .padding(Socle.M.space4)
        .sheet(isPresented: $adding) { AddAccountView() }
        .sheet(item: $editing) { EditAccountView(account: $0) }
        .sheet(item: $authorizing) { AddAccountView(existing: $0) }
    }

    private func row(_ a: Account) -> some View {
        let p = Providers.find(a.provider)
        let st = mounter.state(a)
        return HStack(spacing: Socle.M.space3) {
            Image(systemName: p?.symbol ?? "cloud").font(.system(size: 20)).frame(width: 28).foregroundStyle(Socle.C.accentText)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.name).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
                Text([p?.name ?? a.provider, a.encrypted ? L("acc.encrypted") : nil].compactMap { $0 }.joined(separator: " · ")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            }
            Spacer()
            if !a.pending { status(st) }
            if a.pending {
                Text(a.hint.isEmpty ? L("acc.pending") : "\(L("acc.pending")) · \(a.hint)").socle(Socle.T.meta).foregroundStyle(Socle.C.warning).lineLimit(1)
                Button(L("acc.authorize")) { authorizing = a }.buttonStyle(SocleButtonStyle(.primary))
            } else {
            switch st {
            case .on(let path):
                Button(L("acc.open")) { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }.buttonStyle(SocleButtonStyle(.secondary))
                Button(L("acc.unmount")) { Task { await mounter.unmount(a) } }.buttonStyle(SocleButtonStyle(.secondary))
            case .starting, .healing:
                ProgressView().controlSize(.small)
            default:
                Button(L("acc.mount")) { Task { await mounter.mount(a) } }.buttonStyle(SocleButtonStyle(.primary))
            }
            }
            Button(L("acc.edit")) { editing = a }.buttonStyle(SocleButtonStyle(.tertiary))
        }
        .padding(Socle.M.space3).background(Socle.C.surface)
    }

    @ViewBuilder private func status(_ s: MountState) -> some View {
        switch s {
        case .off: Text(L("acc.status.off")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
        case .starting: Text(L("acc.status.starting")).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
        case .healing: Text(L("acc.status.heal")).socle(Socle.T.meta).foregroundStyle(Socle.C.warning)
        case .on: Label(L("acc.status.on"), systemImage: "circle.fill").socle(Socle.T.meta).foregroundStyle(Socle.C.success)
        case .error(let e): Text(L("acc.status.error", e)).socle(Socle.T.meta).foregroundStyle(Socle.C.danger).lineLimit(2).frame(maxWidth: 220, alignment: .trailing)
        }
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var secret = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).socle(Socle.T.label).foregroundStyle(Socle.C.textMuted)
            if secret { SecureField("", text: $text).socleField() } else { TextField("", text: $text).socleField() }
        }
    }
}

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    var existing: Account? = nil
    @State private var provider: Provider?
    @State private var name = ""
    @State private var values: [String: String] = [:]
    @State private var encrypt = false
    @State private var cryptPw = ""
    @State private var atLogin = false
    @State private var busy = false
    @State private var error = ""
    @State private var codeHelp: String?
    @State private var code = ""
    @State private var codeCont: CheckedContinuation<String?, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(L("add.title")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            if provider == nil {
                Text(L("add.provider")).socle(Socle.T.label).foregroundStyle(Socle.C.textMuted)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Socle.M.space2)], spacing: Socle.M.space2) {
                        ForEach(Providers.all) { p in
                            Button { pick(p) } label: {
                                HStack { Image(systemName: p.symbol); Text(p.name); Spacer() }.frame(maxWidth: .infinity)
                            }.buttonStyle(SocleButtonStyle(.secondary))
                        }
                    }
                }
            } else if let p = provider {
                ScrollView { VStack(alignment: .leading, spacing: Socle.M.space3) {
                    HStack { Image(systemName: p.symbol).foregroundStyle(Socle.C.accentText); Text(p.name).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
                        Spacer(); if !busy, existing == nil { Button(L("add.provider")) { provider = nil }.buttonStyle(SocleButtonStyle(.tertiary)) } }
                    LabeledField(label: L("add.name"), text: $name)
                    ForEach(p.fields) { f in LabeledField(label: L(f.label), text: binding(f.key), secret: f.secret) }
                    if p.oauth { Text(L("add.oauth.hint")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle) }
                    Toggle(L("add.encrypt"), isOn: $encrypt).toggleStyle(.checkbox).socle(Socle.T.body)
                    if encrypt {
                        LabeledField(label: L("add.encrypt.pw"), text: $cryptPw, secret: true)
                        Text(L("add.encrypt.hint")).socle(Socle.T.meta).foregroundStyle(Socle.C.warning)
                    }
                    Toggle(L("add.login"), isOn: $atLogin).toggleStyle(.checkbox).socle(Socle.T.body)
                    if let h = codeHelp {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(h.isEmpty ? L("add.2fa") : h).socle(Socle.T.body).foregroundStyle(Socle.C.textStrong)
                            HStack { TextField("", text: $code).socleField(); Button(L("add.2fa.ok")) { codeHelp = nil; codeCont?.resume(returning: code); codeCont = nil; code = "" }.buttonStyle(SocleButtonStyle(.primary)) }
                        }
                    }
                    if !error.isEmpty { Text(error).socle(Socle.T.body).foregroundStyle(Socle.C.danger) }
                } }
            }
            HStack {
                if busy { ProgressView().controlSize(.small); Text(L("add.connecting")).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted) }
                Spacer()
                Button(L("add.cancel")) { codeCont?.resume(returning: nil); dismiss() }.buttonStyle(SocleButtonStyle(.secondary))
                if provider != nil { Button(L("add.connect")) { connect() }.buttonStyle(SocleButtonStyle(.primary)).disabled(busy) }
            }
        }
        .padding(Socle.M.space5).frame(width: 560, height: 560).background(Socle.C.surface)
        .onAppear {
            guard let e = existing, provider == nil, let p = Providers.find(e.provider) else { return }
            pick(p); name = e.name; atLogin = e.atLogin
            if !e.hint.isEmpty, let f = p.fields.first(where: { $0.key == "user" || $0.key == "apple_id" }) { values[f.key] = e.hint }
        }
    }

    private func pick(_ p: Provider) { provider = p; name = p.name; values = [:]; error = "" }
    private func binding(_ k: String) -> Binding<String> { Binding(get: { values[k] ?? "" }, set: { values[k] = $0 }) }

    private func connect() {
        guard let p = provider else { return }
        let missing = p.fields.contains { !$0.optional && (values[$0.key] ?? "").isEmpty } || name.trimmingCharacters(in: .whitespaces).isEmpty || (encrypt && cryptPw.isEmpty)
        if missing { error = L("add.required"); return }
        error = ""; busy = true
        var acc = existing ?? Account(name: name, remote: "", provider: p.id)
        acc.name = name.trimmingCharacters(in: .whitespaces); acc.remote = Store.shared.uniqueRemote(p.id); acc.provider = p.id
        acc.encrypted = encrypt; acc.atLogin = atLogin; acc.pending = false
        Task {
            do {
                try await Rclone.createRemote(name: acc.remote, provider: p, values: values) { help in
                    await withCheckedContinuation { c in codeCont = c; codeHelp = help }
                }
                if encrypt { Keychain.set(acc.id.uuidString, cryptPw) }
                if existing != nil { Store.shared.update(acc) } else { Store.shared.add(acc) }
                dismiss()
            } catch {
                busy = false
                let m = error.localizedDescription
                self.error = m == "—" ? "" : L("add.error", m)
            }
        }
    }
}

struct EditAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State var account: Account
    @State private var confirm = false
    init(account: Account) { _account = State(initialValue: account) }

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(L("edit.title")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            LabeledField(label: L("add.name"), text: $account.name)
            Toggle(L("add.login"), isOn: $account.atLogin).toggleStyle(.checkbox).socle(Socle.T.body)
            Text(L("edit.cache")).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong).padding(.top, Socle.M.space2)
            Picker("", selection: $account.cacheMode) {
                Text(L("edit.mode.minimal")).tag("minimal"); Text(L("edit.mode.balanced")).tag("balanced"); Text(L("edit.mode.offline")).tag("offline")
            }.pickerStyle(.segmented).labelsHidden()
            Text(L("edit.mode.hint." + account.cacheMode)).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            if account.cacheMode == "offline" {
                Stepper("\(L("edit.cache.gb")) : \(account.cacheGB)", value: $account.cacheGB, in: 1...500).socle(Socle.T.body)
                Stepper("\(L("edit.cache.days")) : \(account.cacheDays)", value: $account.cacheDays, in: 1...365).socle(Socle.T.body)
            }
            Spacer()
            HStack {
                Button(L("edit.delete")) { confirm = true }.buttonStyle(SocleButtonStyle(.tertiary)).foregroundStyle(Socle.C.danger)
                Spacer()
                Button(L("add.cancel")) { dismiss() }.buttonStyle(SocleButtonStyle(.secondary))
                Button(L("edit.save")) { Store.shared.update(account); dismiss() }.buttonStyle(SocleButtonStyle(.primary))
            }
        }
        .padding(Socle.M.space5).frame(width: 460, height: 400).background(Socle.C.surface)
        .confirmationDialog(L("edit.delete.confirm"), isPresented: $confirm) {
            Button(L("edit.delete"), role: .destructive) {
                Task { await Mounter.shared.unmount(account); await Rclone.deleteRemote(account.remote); Store.shared.remove(account); dismiss() }
            }
        }
    }
}

// MARK: Veille

struct VeilleView: View {
    @ObservedObject private var veille = Veille.shared
    private static let df: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(L("watch.title")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            Text(L("watch.intro")).socle(Socle.T.body).foregroundStyle(Socle.C.textMuted)
            HStack {
                Button(veille.running ? L("watch.running") : L("watch.run")) { Task { await veille.run() } }.buttonStyle(SocleButtonStyle(.primary)).disabled(veille.running)
                Button(L("watch.markread")) { veille.markAllRead() }.buttonStyle(SocleButtonStyle(.secondary))
                Button(L("watch.report")) { NSWorkspace.shared.open(veille.reportURL) }.buttonStyle(SocleButtonStyle(.secondary))
                Spacer()
                Text(veille.last.map { L("watch.last", Self.df.string(from: $0)) } ?? L("watch.never")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            }
            if veille.findings.isEmpty {
                Text(L("watch.empty")).socle(Socle.T.body).foregroundStyle(Socle.C.success).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(spacing: 1) { ForEach(veille.findings) { f in item(f) } } }.background(Socle.C.border)
            }
        }.padding(Socle.M.space4)
    }

    private func item(_ f: Veille.Finding) -> some View {
        let color: Color = f.kind == .code ? Socle.C.danger : f.kind == .user ? Socle.C.warning : Socle.C.accentText
        let label = f.kind == .code ? L("watch.kind.code") : f.kind == .user ? L("watch.kind.user") : L("watch.kind.info")
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).socle(Socle.T.labelStrong).foregroundStyle(color)
                Text(f.service).socle(Socle.T.label).foregroundStyle(Socle.C.textStrong)
                if !f.read && f.kind != .info { Circle().fill(color).frame(width: 6, height: 6) }
                Spacer()
                Text(Self.df.string(from: f.date)).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            }
            Text(f.title).socle(Socle.T.body).foregroundStyle(Socle.C.text)
            if !f.detail.isEmpty { Text(f.detail).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted).textSelection(.enabled) }
            if let u = f.url, let url = URL(string: u) { Link(u, destination: url).socle(Socle.T.meta) }
        }
        .padding(Socle.M.space3).frame(maxWidth: .infinity, alignment: .leading).background(Socle.C.surface)
    }
}

// MARK: Réglages

struct SettingsView: View {
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var engine = ""
    @ObservedObject private var upd = Updater.shared
    @AppStorage("autoUpdate") private var auto = true

    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space4) {
            Toggle(L("set.login"), isOn: $login).toggleStyle(.checkbox).socle(Socle.T.body)
                .onChange(of: login) { on in do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { login = SMAppService.mainApp.status == .enabled } }
            Text(L("set.engine", engine)).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            Divider().overlay(Socle.C.border)
            Text(L("upd.title")).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
            Toggle(L("upd.auto"), isOn: $auto).toggleStyle(.checkbox).socle(Socle.T.body)
            HStack {
                Button(L("upd.check")) { Task { await upd.check() } }.buttonStyle(SocleButtonStyle(.secondary))
                switch upd.state {
                case .checking: Text(L("upd.checking")).socle(Socle.T.meta)
                case .upToDate: Text(L("upd.uptodate")).socle(Socle.T.meta).foregroundStyle(Socle.C.success)
                case .available(let v): Text(L("upd.available", v)).socle(Socle.T.meta); Button(L("upd.install")) { Task { await upd.install() } }.buttonStyle(SocleButtonStyle(.primary))
                case .downloading: Text(L("upd.downloading")).socle(Socle.T.meta)
                case .failed(let e): Text(e).socle(Socle.T.meta).foregroundStyle(Socle.C.danger)
                case .idle: EmptyView()
                }
            }
            Divider().overlay(Socle.C.border)
            Button(L("set.about")) { About.show() }.buttonStyle(SocleButtonStyle(.secondary))
            Spacer()
        }
        .padding(Socle.M.space5).frame(maxWidth: .infinity, alignment: .leading)
        .task { engine = await Rclone.version() }
    }
}
