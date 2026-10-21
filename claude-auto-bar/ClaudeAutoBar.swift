// ClaudeAutoBar — cotas das contas Claude na barra de menu, no estilo do Stats.
//
// Mostra uma mini barra por conta (uso da janela mais cheia, 5h ou 7d) e, ao
// clicar, um painel com uso de 5h/7d, horário de reset, login, conta em uso e a
// próxima da fila. Os dados vêm de `claude-auto status --json`, então fila,
// limiar e regra de "conta cheia" ficam num lugar só (o script).
//
// Atualiza quando o claude-auto grava algo em ~/.local/state/claude-auto
// (statusline, hooks, presença) e a cada 30 s, para resets que passam sozinhos.
//
// Build: claude-auto-bar/build.sh. Prévia sem barra de menu:
//   ClaudeAutoBar --snapshot painel.png

import AppKit
import SwiftUI

// MARK: - Modelo (espelha `claude-auto status --json`)

struct UsageWindow: Decodable {
    let used_percentage: Double
    let resets_at: Double
}

struct RateLimits: Decodable {
    let five_hour: UsageWindow?
    let seven_day: UsageWindow?
}

struct Usage: Decodable {
    let rate_limits: RateLimits?
    let updated_at: Double?
}

struct AccountInfo: Decodable {
    let email: String?
    let name: String?
}

struct Account: Decodable, Identifiable {
    let name: String
    let exists: Bool
    let in_use: Int
    let free_at: Double
    let usage: Usage?
    let account: AccountInfo?

    var id: String { name }

    /// Janela só conta enquanto o reset não passou (depois disso zerou).
    func window(_ kp: KeyPath<RateLimits, UsageWindow?>, now: Date) -> UsageWindow? {
        guard let w = usage?.rate_limits?[keyPath: kp], w.resets_at > now.timeIntervalSince1970 else { return nil }
        return w
    }

    func peak(now: Date) -> Double? {
        [window(\.five_hour, now: now), window(\.seven_day, now: now)]
            .compactMap { $0?.used_percentage }.max()
    }

    func isFull(now: Date) -> Bool { free_at > now.timeIntervalSince1970 }

    /// Statusline gravou há pouco: alguma sessão (com ou sem wrapper) está usando.
    func recentlyActive(now: Date) -> Bool {
        guard let t = usage?.updated_at else { return false }
        return now.timeIntervalSince1970 - t < 300
    }

    var shortName: String { String(name.prefix(1)).uppercased() }
}

struct Snapshot: Decodable {
    let threshold: Double
    let next: String?
    let accounts: [Account]
}

// MARK: - Fonte de dados

@MainActor
final class Store: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var error: String?
    @Published private(set) var now = Date()

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var cli: String { home.appendingPathComponent(".local/bin/claude-auto").path }
    private var stateDir: URL { home.appendingPathComponent(".local/state/claude-auto") }
    private var timer: Timer?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private var started = false

    func start() {
        guard !started else { return }  // o .task do rótulo pode rodar mais de uma vez
        started = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        watch()
    }

    func refresh() {
        let cli = cli
        Task.detached {
            let result = Self.run(cli, ["status", "--json"])
            await MainActor.run { self.apply(result) }
        }
    }

    /// Versão síncrona, para o modo --snapshot.
    func refreshNow() { apply(Self.run(cli, ["status", "--json"])) }

    func unblock(_ name: String) {
        let cli = cli
        Task.detached {
            _ = Self.run(cli, ["unblock", name])
            await MainActor.run { self.refresh() }
        }
    }

    private func apply(_ result: (status: Int32, out: Data)) {
        now = Date()
        guard result.status == 0 else {
            error = "claude-auto status falhou (\(result.status)); rode `claude-auto doctor`"
            return
        }
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: result.out)
            error = nil
        } catch {
            self.error = "resposta inesperada do claude-auto: \(error.localizedDescription)"
        }
    }

    /// Diretórios onde statusline, hooks e wrapper gravam: qualquer escrita
    /// (o mv atômico conta) dispara uma atualização, agrupada em 0,7 s.
    private func watch() {
        for sub in ["usage", "blocked", "run"] {
            let dir = stateDir.appendingPathComponent(sub)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            }
            src.setCancelHandler { close(fd) }
            src.resume()
            sources.append(src)
        }
    }

    private func scheduleRefresh() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: item)
    }

    nonisolated static func run(_ path: String, _ args: [String]) -> (status: Int32, out: Data) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (127, Data()) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, data)
    }
}

// MARK: - Cores e textos

func levelColor(_ pct: Double, threshold: Double) -> Color {
    if pct >= threshold { return .red }
    if pct >= 70 { return .orange }
    return .green
}

func levelNSColor(_ pct: Double, threshold: Double) -> NSColor {
    if pct >= threshold { return .systemRed }
    if pct >= 70 { return .systemOrange }
    return .systemGreen
}

let ptBR = Locale(identifier: "pt_BR")

func resetText(_ epoch: Double, now: Date) -> String {
    let date = Date(timeIntervalSince1970: epoch)
    let f = DateFormatter()
    f.locale = ptBR
    f.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"
    return f.string(from: date)
}

func agoText(_ epoch: Double?, now: Date) -> String {
    guard let epoch else { return "sem dados ainda" }
    let min = Int((now.timeIntervalSince1970 - epoch) / 60)
    if min < 1 { return "atualizado agora" }
    if min < 60 { return "atualizado há \(min) min" }
    if min < 60 * 48 { return "atualizado há \(min / 60) h" }
    return "atualizado há \(min / 1440) dias"
}

// MARK: - Barra de menu

/// Mini barras verticais, uma por conta, como o gráfico de CPU do Stats.
func barsImage(_ snap: Snapshot?, now: Date) -> NSImage {
    let accounts = snap?.accounts ?? []
    let threshold = snap?.threshold ?? 95
    let barW: CGFloat = 4, gap: CGFloat = 2, h: CGFloat = 15
    let n = max(accounts.count, 1)
    let size = NSSize(width: CGFloat(n) * barW + CGFloat(n - 1) * gap, height: h)
    let image = NSImage(size: size, flipped: false) { _ in
        for (i, a) in accounts.enumerated() {
            let x = CGFloat(i) * (barW + gap)
            let track = NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: barW, height: h), xRadius: 1.2, yRadius: 1.2)
            NSColor.labelColor.withAlphaComponent(0.22).setFill()
            track.fill()
            let pct = a.isFull(now: now) ? 100 : (a.peak(now: now) ?? 0)
            guard a.exists, a.account?.email != nil else { continue }
            let fillH = max(1.5, h * CGFloat(min(pct, 100)) / 100)
            let fill = NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: barW, height: fillH), xRadius: 1.2, yRadius: 1.2)
            levelNSColor(pct, threshold: threshold).setFill()
            fill.fill()
        }
        return true
    }
    image.isTemplate = false
    return image
}

/// Conta mostrada no texto: a que está em uso; senão a que usou por último;
/// senão a próxima da fila.
func focusAccount(_ snap: Snapshot, now: Date) -> Account? {
    if let a = snap.accounts.first(where: { $0.in_use > 0 }) { return a }
    let recent = snap.accounts.filter { $0.recentlyActive(now: now) }
        .max { ($0.usage?.updated_at ?? 0) < ($1.usage?.updated_at ?? 0) }
    if let recent { return recent }
    return snap.accounts.first { $0.name == snap.next }
}

struct MenuBarLabel: View {
    @ObservedObject var store: Store

    var body: some View {
        let snap = store.snapshot
        HStack(spacing: 4) {
            Image(nsImage: barsImage(snap, now: store.now))
            Text(text(snap)).monospacedDigit()
        }
    }

    private func text(_ snap: Snapshot?) -> String {
        guard let snap else { return "—" }
        if snap.next == nil { return "todas cheias" }
        guard let a = focusAccount(snap, now: store.now) else { return "—" }
        let pct = a.peak(now: store.now).map { "\(Int($0))%" } ?? "—"
        return "\(a.shortName) \(pct)"
    }
}

// MARK: - Painel

struct UsageBar: View {
    let label: String
    let window: UsageWindow?
    let threshold: Double
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    if let w = window {
                        Capsule()
                            .fill(levelColor(w.used_percentage, threshold: threshold))
                            .frame(width: max(4, g.size.width * min(w.used_percentage, 100) / 100))
                    }
                }
            }
            .frame(height: 6)
            Text(window.map { "\(Int($0.used_percentage))%" } ?? "—")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .frame(width: 34, alignment: .trailing)
            Text(window.map { "↻ " + resetText($0.resets_at, now: now) } ?? "")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

struct AccountRow: View {
    let account: Account
    let snap: Snapshot
    let now: Date
    let unblock: (String) -> Void

    private var state: (text: String, color: Color) {
        let a = account
        if !a.exists { return ("sem perfil", .gray) }
        if a.account?.email == nil { return ("sem login", .gray) }
        if a.isFull(now: now) {
            return ("cheia até " + resetText(a.free_at, now: now), .red)
        }
        if a.in_use > 0 { return (a.in_use > 1 ? "em uso ×\(a.in_use)" : "em uso", .blue) }
        if a.recentlyActive(now: now) { return ("ativa", .blue) }
        return ("livre", .green)
    }

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(s.color).frame(width: 7, height: 7)
                Text(account.name.capitalized).font(.system(size: 12, weight: .semibold))
                if account.name == snap.next {
                    Text("próxima")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                }
                Spacer()
                Text(s.text).font(.system(size: 11))
                    .foregroundStyle(s.color == .gray ? AnyShapeStyle(.secondary) : AnyShapeStyle(s.color))
            }
            if let email = account.account?.email {
                Text(email).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            }
            UsageBar(label: "5h", window: account.window(\.five_hour, now: now), threshold: snap.threshold, now: now)
            UsageBar(label: "7d", window: account.window(\.seven_day, now: now), threshold: snap.threshold, now: now)
            HStack {
                Text(agoText(account.usage?.updated_at, now: now))
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                Spacer()
                if account.isFull(now: now) {
                    Button("Liberar") { unblock(account.name) }
                        .controlSize(.mini)
                        .help("Tira o bloqueio; vale se a cota já voltou antes do previsto")
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

struct Panel: View {
    @ObservedObject var store: Store
    var interactive = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Contas Claude").font(.system(size: 13, weight: .bold))
                Spacer()
                if interactive {
                    Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help("Atualizar")
                }
            }
            if let snap = store.snapshot {
                ForEach(snap.accounts) { a in
                    AccountRow(account: a, snap: snap, now: store.now, unblock: store.unblock)
                }
                footer(snap)
            } else {
                Text(store.error ?? "carregando…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 330)
        .onAppear { if interactive { store.refresh() } }
    }

    private func footer(_ snap: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = store.error {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
            }
            HStack {
                Text("fila " + snap.accounts.map(\.shortName).joined(separator: "→") + " · troca em \(Int(snap.threshold))%")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                if interactive {
                    Button("Sair") { NSApp.terminate(nil) }.controlSize(.small)
                }
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - App

@main
struct ClaudeAutoBarApp: App {
    @StateObject private var store = Store()

    init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Self.snapshot(to: args[i + 1])
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(store: store)
        } label: {
            MenuBarLabel(store: store)
                .task { store.start() }
        }
        .menuBarExtraStyle(.window)
    }

    /// Renderiza painel e rótulo num PNG, para conferir o visual sem a barra.
    @MainActor
    static func snapshot(to path: String) {
        let store = Store()
        store.refreshNow()
        let view = VStack(spacing: 10) {
            HStack { MenuBarLabel(store: store).padding(6) }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
            Panel(store: store, interactive: false)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .windowBackgroundColor)))
        }
        .padding(16)
        .background(Color(nsColor: .underPageBackgroundColor))
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("falha ao renderizar\n".data(using: .utf8)!)
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
