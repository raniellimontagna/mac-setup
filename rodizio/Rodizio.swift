// Rodízio — as contas Claude na barra de menus. Passa a próxima.
//
// Par visual do claude-auto: na barra fica um espeto com um pedaço por conta
// (cheio = conta com folga, vazado = cheia) e, se ligado nos Ajustes, o bloco
// com a conta em uso e o percentual dela. O clique abre um painel de vidro, no
// estilo da Central de Controle, com um módulo por conta: e-mail logado, uso
// de 5h e 7d com horário de reset, histórico das últimas 24 h e o estado
// (livre, ativa, em uso pelo claude-auto, cheia até HH:MM).
//
// Os dados vêm de `claude-auto status --json`: fila, limiar e regra de "conta
// cheia" ficam num lugar só (o script). Atualiza quando o claude-auto grava
// algo em ~/.local/state/claude-auto e a cada 30 s, para os resets que passam
// sozinhos. Avisa (notificação) quando uma conta enche, libera ou quando o
// claude-auto troca de conta. Grava o retrato para os widgets (Widget.swift)
// e pede para eles redesenharem quando algo importante muda.
//
// Build: rodizio/build.sh. Prévias sem a barra de menus:
//   Rodizio --snapshot paineis.png | --widgets widgets.png | --icon icone-1024.png

import AppKit
import Combine
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - Fonte de dados

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var error: String?
    @Published private(set) var now = Date()
    @Published private(set) var history: [String: [Sample]] = [:]

    /// Chamado a cada leitura nova: (anterior, quando foi lida, nova, agora).
    var onUpdate: ((Snapshot?, Date, Snapshot, Date) -> Void)?

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var cli: String { home.appendingPathComponent(".local/bin/claude-auto").path }
    private var stateDir: URL { home.appendingPathComponent(".local/state/claude-auto") }
    private var historyURL: URL { home.appendingPathComponent("Library/Application Support/Rodizio/history.json") }
    private var timer: Timer?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private var started = false
    private var widgetData: Data?
    private var widgetSignature = ""
    private var widgetReloadedAt = Date.distantPast

    init() { loadHistory() }

    func start() {
        guard !started else { return }
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

    /// Versão síncrona, para as prévias.
    func refreshNow() { apply(Self.run(cli, ["status", "--json"])) }

    func unblock(_ name: String) {
        let cli = cli
        Task.detached {
            _ = Self.run(cli, ["unblock", name])
            await MainActor.run { self.refresh() }
        }
    }

    private func apply(_ result: (status: Int32, out: Data)) {
        let before = now
        now = Date()
        guard result.status == 0 else {
            error = "claude-auto status falhou (\(result.status)); rode `claude-auto doctor`"
            return
        }
        do {
            let new = try JSONDecoder().decode(Snapshot.self, from: result.out)
            let old = snapshot
            snapshot = new
            error = nil
            record(new)
            if started { publishWidget(new) }
            onUpdate?(old, before, new, now)
        } catch {
            self.error = "resposta inesperada do claude-auto: \(error.localizedDescription)"
        }
    }

    /// Grava o arquivo que o widget lê. Redesenhar o widget gasta cota do
    /// sistema, então só pede na hora quando muda o que ele mostra de relance
    /// (folga, conta em uso, próxima, faixa de 5 pontos de uso); o resto, no
    /// máximo a cada 10 min.
    private func publishWidget(_ snap: Snapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(WidgetPayload(snapshot: snap, history: history)), data != widgetData else { return }
        widgetData = data
        try? FileManager.default.createDirectory(at: WidgetPayload.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: WidgetPayload.url, options: .atomic)

        let signature = (snap.next ?? "-") + snap.accounts.map { a in
            "\(a.name):\(a.hasRoom(now: now)):\(a.in_use > 0):\(Int((a.peak(now: now) ?? 0) / 5))"
        }.joined(separator: ",")
        if signature != widgetSignature || now.timeIntervalSince(widgetReloadedAt) > 600 {
            widgetSignature = signature
            widgetReloadedAt = now
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // Histórico de 24 h da janela de 5h: grava quando o uso muda 2 pontos ou a
    // cada 10 min, para a linha ter forma sem encher o arquivo. Dentro de uma
    // janela o uso só sobe; uma queda pequena é leitura atrasada de outra sessão
    // na mesma conta (70, 71, 70…) e vira ruído na linha, então é ignorada.
    // Queda grande é reset da janela e entra.
    private func record(_ snap: Snapshot) {
        let t = now.timeIntervalSince1970
        var changed = false
        for a in snap.accounts where a.loggedIn {
            var p = a.window(\.five_hour, now: now)?.used_percentage ?? 0
            var list = history[a.name] ?? []
            if let last = list.last {
                if p < last.p, p > last.p - 10 { p = last.p }
                if abs(last.p - p) < 2, t - last.t < 600 { continue }
            }
            list.append(Sample(t: t, p: p))
            list.removeAll { $0.t < t - 86_400 }
            history[a.name] = list
            changed = true
        }
        if changed { saveHistory() }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let saved = try? JSONDecoder().decode([String: [Sample]].self, from: data) else { return }
        let cutoff = Date().timeIntervalSince1970 - 86_400
        history = saved.mapValues { $0.filter { $0.t >= cutoff } }
    }

    private func saveHistory() {
        try? FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: historyURL, options: .atomic) }
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
            src.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scheduleRefresh() } }
            src.setCancelHandler { close(fd) }
            src.resume()
            sources.append(src)
        }
    }

    private func scheduleRefresh() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.refresh() } }
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

// MARK: - Ajustes

/// Abrir junto com o Mac: o LaunchAgent que o build.sh instala. Desligar usa
/// `launchctl disable`, que vale para o próximo login sem derrubar o app agora.
enum LoginItem {
    static let label = "com.rannimontagna.rodizio"
    static var plist: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var installed: Bool { FileManager.default.fileExists(atPath: plist.path) }

    static func isEnabled() -> Bool {
        guard installed else { return false }
        let out = String(decoding: Store.run("/bin/launchctl", ["print-disabled", "gui/\(getuid())"]).out, as: UTF8.self)
        return !out.split(separator: "\n").contains { $0.contains("\"\(label)\"") && $0.contains("disabled") }
    }

    static func set(_ on: Bool) {
        _ = Store.run("/bin/launchctl", [on ? "enable" : "disable", "gui/\(getuid())/\(label)"])
    }
}

@MainActor
final class Prefs: ObservableObject {
    static let shared = Prefs()
    /// Onde salvar; nil nas prévias, que mudam os ajustes só para desenhar.
    private let defaults: UserDefaults?

    /// Mini barras coloridas (uma por conta) ao lado do espeto.
    @Published var showBars: Bool { didSet { defaults?.set(showBars, forKey: "showBars") } }
    /// Bloco com a conta em foco e o percentual dela.
    @Published var showBlock: Bool { didSet { defaults?.set(showBlock, forKey: "showBlock") } }
    @Published var notify: Bool {
        didSet {
            defaults?.set(notify, forKey: "notify")
            if notify, defaults != nil { Notifier.requestAuthorization() }
        }
    }
    @Published private(set) var launchAtLogin = LoginItem.isEnabled()

    init(persist: Bool = true) {
        let saved = UserDefaults.standard
        defaults = persist ? saved : nil
        showBars = saved.object(forKey: "showBars") as? Bool ?? false
        showBlock = saved.object(forKey: "showBlock") as? Bool ?? true
        notify = saved.object(forKey: "notify") as? Bool ?? true
    }

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchAtLogin = LoginItem.isEnabled()
    }
}

// MARK: - Avisos

@MainActor
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Compara duas leituras seguidas. A primeira leitura (ao abrir) não avisa.
    static func diff(old: Snapshot?, oldNow: Date, new: Snapshot, now: Date) {
        guard let old, Prefs.shared.notify else { return }
        let before = Dictionary(old.accounts.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        for a in new.accounts where a.loggedIn {
            guard let b = before[a.name] else { continue }
            let wasFull = b.isFull(now: oldNow), isFull = a.isFull(now: now)
            if !wasFull && isFull {
                let next = new.next.map { "próxima: \($0.capitalized)" } ?? "todas as contas estão cheias"
                post("\(a.title) está cheia", "Libera às \(timeText(a.free_at, now: now)) · \(next)")
            } else if wasFull && !isFull {
                post("\(a.title) liberou", "A cota voltou e ela entra de novo na fila.")
            }
        }
        let from = old.accounts.filter { $0.in_use > 0 }.map(\.name)
        let to = new.accounts.filter { $0.in_use > 0 }.map(\.name)
        if let f = from.first, let t = to.first(where: { !from.contains($0) }), !to.contains(f) {
            post("claude-auto passou para \(t.capitalized)", "A sessão segue de onde parou em \(f.capitalized).")
        }
    }

    /// Conta → reset da janela em que já avisou que ela ia encher (um aviso por janela).
    private static var warned: [String: Double] = [:]

    /// Aviso antecipado: uma conta em uso deve chegar ao limiar em até 20 min.
    static func forecast(_ snap: Snapshot, history: [String: [Sample]], now: Date) {
        guard Prefs.shared.notify else { return }
        for a in snap.accounts where a.in_use > 0 || a.recentlyActive(now: now) {
            guard let f = a.forecast(history: history[a.name] ?? [], threshold: snap.threshold, now: now),
                  let reset = a.window(\.five_hour, now: now)?.resets_at,
                  f.minutesLeft(now: now) <= 20, warned[a.name] != reset else { continue }
            warned[a.name] = reset
            let next = snap.after(a.name).map { "Depois dela vem \($0.capitalized)." } ?? "Nenhuma outra conta tem folga agora."
            post("\(a.title) deve encher às \(timeText(f.fullAt.timeIntervalSince1970, now: now))",
                 "No ritmo atual, faltam ~\(f.minutesLeft(now: now)) min. \(next)")
        }
    }
}

// MARK: - Marca

extension NSColor {
    static let folga = NSColor(Color.folga)
    static let alerta = NSColor(Color.alerta)
    static let cheia = NSColor(Color.cheia)
}

func usageNSTint(_ pct: Double, threshold: Double) -> NSColor {
    pct >= threshold ? .cheia : pct >= 70 ? .alerta : .folga
}

/// Ícone do app: espeto sobre carvão, com a brasa embaixo.
struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        let radius = size * 0.225
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x33271F), .carvao], startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(RadialGradient(colors: [Color.brasa.opacity(0.9), Color.brasa.opacity(0)], center: .center,
                                     startRadius: 0, endRadius: size * 0.42))
                .frame(width: size * 1.1, height: size * 0.55)
                .offset(y: size * 0.42)
            Skewer(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Cápsula de ação na cor da marca.
struct CapsuleLabel: View {
    enum Style { case prominent, outline, secondary }
    let title: String
    var systemImage: String?
    var style: Style = .prominent
    var fullWidth = false
    @Environment(\.colorScheme) private var scheme

    private var ink: Color { scheme == .dark ? .brasaClara : .brasa }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title).lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(style == .prominent ? AnyShapeStyle(.white) : style == .outline ? AnyShapeStyle(ink) : AnyShapeStyle(.primary))
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(style == .prominent ? AnyShapeStyle(Color.brasa)
                      : style == .outline ? AnyShapeStyle(Color.brasa.opacity(0.1)) : AnyShapeStyle(.fill.secondary))
                .overlay(Capsule().strokeBorder(ink, lineWidth: style == .outline ? 1.1 : 0))
        }
        .contentShape(Capsule())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// Cartão no estilo dos módulos da Central de Controle.
    func module() -> some View {
        padding(11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
            )
    }
}

// MARK: - Ícone da barra de menus

enum MenuBarArt {
    /// Espeto em traço de sistema: um pedaço por conta, cheio se a conta tem
    /// folga e vazado se está cheia (ou sem login).
    static func drawSkewer(at origin: NSPoint, room: [Bool], ink: NSColor) -> CGFloat {
        let h: CGFloat = 16, line: CGFloat = 1.3, chunkW: CGFloat = 4.4, gap: CGFloat = 1.6
        let n = max(room.count, 1)
        let start: CGFloat = 6.4
        let rodEnd = start + CGFloat(n) * (chunkW + gap) + 1.5
        let y = origin.y + h / 2
        ink.setStroke()
        ink.setFill()

        let ring = NSBezierPath(ovalIn: NSRect(x: origin.x + 0.8, y: y - 2.1, width: 4.2, height: 4.2))
        ring.lineWidth = line
        ring.stroke()

        let rod = NSBezierPath()
        rod.move(to: NSPoint(x: origin.x + 5, y: y))
        rod.line(to: NSPoint(x: origin.x + rodEnd, y: y))
        rod.lineWidth = line
        rod.lineCapStyle = .round
        rod.stroke()
        let tip = NSBezierPath()
        tip.move(to: NSPoint(x: origin.x + rodEnd, y: y - 1.6))
        tip.line(to: NSPoint(x: origin.x + rodEnd + 2.6, y: y))
        tip.line(to: NSPoint(x: origin.x + rodEnd, y: y + 1.6))
        tip.close()
        tip.fill()

        for i in 0..<n {
            let x = origin.x + start + CGFloat(i) * (chunkW + gap)
            let rect = NSRect(x: x, y: y - 4.6, width: chunkW, height: 9.2)
            let chunk = NSBezierPath(roundedRect: rect, xRadius: 1.4, yRadius: 1.4)
            if i < room.count, room[i] {
                chunk.fill()
            } else {
                // vazado: apaga o espeto por dentro e desenha só o contorno
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), xRadius: 1, yRadius: 1).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                let outline = NSBezierPath(roundedRect: rect.insetBy(dx: line / 2, dy: line / 2), xRadius: 1.2, yRadius: 1.2)
                outline.lineWidth = line
                outline.stroke()
            }
        }
        return rodEnd + 3
    }

    /// Barra de menus completa. Sem as mini barras coloridas, a imagem é
    /// template (segue claro/escuro e o realce do clique); com elas, as partes
    /// monocromáticas usam a cor do texto da barra.
    @MainActor
    static func image(_ snap: Snapshot?, prefs: Prefs, now: Date, ink fixedInk: NSColor? = nil) -> NSImage {
        let accounts = snap?.accounts ?? []
        let threshold = snap?.threshold ?? 95
        let room = accounts.map { $0.hasRoom(now: now) }
        // Copiados aqui: o desenho roda fora do main actor, na hora de pintar.
        let showBars = prefs.showBars
        let template = !showBars && fixedInk == nil
        let ink = fixedInk ?? (template ? NSColor.black : NSColor.labelColor)

        let labelFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        var block: (label: String, value: String)?
        if prefs.showBlock, let snap {
            if snap.next == nil {
                block = ("TODAS", "cheias")
            } else if let a = snap.focus(now: now) {
                let pct = a.peak(now: now).map { "\(Int($0.rounded()))%" } ?? "—"
                block = ("\(a.initial) · 5H", pct)
            }
        }
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: ink]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: ink]
        // Largura fixa (a de "100%"): o ícone não pula quando o número muda.
        let blockW = block.map {
            max(("100%" as NSString).size(withAttributes: valueAttrs).width,
                ($0.label as NSString).size(withAttributes: labelAttrs).width,
                ($0.value as NSString).size(withAttributes: valueAttrs).width)
        } ?? 0
        let skewerW = 6.4 + CGFloat(max(room.count, 1)) * 6 + 4.5
        let barsW: CGFloat = showBars ? CGFloat(max(accounts.count, 1)) * 6 - 2 : 0
        let height: CGFloat = 22
        let width = skewerW + (showBars ? 5 + barsW : 0) + (block != nil ? 5 + blockW : 0)

        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            var x = drawSkewer(at: NSPoint(x: 0, y: (height - 16) / 2), room: room, ink: ink)
            if showBars {
                x += 2
                for (i, a) in accounts.enumerated() {
                    let bx = x + CGFloat(i) * 6, bh: CGFloat = 14, by = (height - bh) / 2
                    ink.withAlphaComponent(0.22).setFill()
                    NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: 4, height: bh), xRadius: 1.2, yRadius: 1.2).fill()
                    guard a.loggedIn else { continue }
                    let pct = a.isFull(now: now) ? 100 : (a.peak(now: now) ?? 0)
                    usageNSTint(pct, threshold: threshold).setFill()
                    let fh = max(1.5, bh * CGFloat(min(pct, 100)) / 100)
                    NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: 4, height: fh), xRadius: 1.2, yRadius: 1.2).fill()
                }
                x += barsW + 3
            }
            if let block {
                x += 2
                let l = block.label as NSString, v = block.value as NSString
                let lw = l.size(withAttributes: labelAttrs).width, vw = v.size(withAttributes: valueAttrs).width
                l.draw(at: NSPoint(x: x + (blockW - lw) / 2, y: 11.5), withAttributes: labelAttrs)
                v.draw(at: NSPoint(x: x + (blockW - vw) / 2, y: -0.5), withAttributes: valueAttrs)
            }
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "Rodízio"
        return image
    }

    static func tooltip(_ snap: Snapshot?, now: Date) -> String {
        guard let snap else { return "Rodízio" }
        var lines = ["Rodízio — \(snap.freeCount(now: now)) de \(snap.accounts.count) contas com folga"]
        lines.append(snap.next.map { "Próxima: \($0.capitalized)" } ?? "Todas as contas estão cheias")
        for a in snap.accounts {
            let pct = a.peak(now: now).map { "\(Int($0))%" } ?? "—"
            lines.append("\(a.title): \(pct) · \(stateText(a.state(now: now), now: now))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Painel

@MainActor
final class PanelUI: ObservableObject {
    @Published var showingSettings = false
}

/// Linha de uma janela de uso: rótulo, barra, % e horário de reset.
struct WindowLine: View {
    let label: String
    let window: UsageWindow
    let threshold: Double
    let now: Date

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)
            Bar(fraction: window.used_percentage / 100, tint: usageTint(window.used_percentage, threshold: threshold))
            Text("\(Int(window.used_percentage))%")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .frame(width: 34, alignment: .trailing)
            Text("zera \(timeText(window.resets_at, now: now))")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
        }
    }
}

struct AccountModule: View {
    let account: Account
    let snap: Snapshot
    let now: Date
    let samples: [Sample]
    var interactive = true
    let onUnblock: () -> Void

    var body: some View {
        let state = account.state(now: now)
        let tint = stateColor(state)
        let peak = account.peak(now: now)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(account.initial)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.gradient))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(account.title).font(.system(size: 13, weight: .semibold))
                        if account.name == snap.next {
                            Text("próxima")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.brasa)
                                .padding(.horizontal, 6).padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.brasa.opacity(0.16)))
                        }
                    }
                    Text(account.account?.email ?? stateText(state, now: now))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(peak.map { "\(Int($0))%" } ?? "—")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(peak.map { usageTint($0, threshold: snap.threshold) } ?? .secondary)
                    Text(stateText(state, now: now))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tint == .gray ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                }
            }
            if let five = account.window(\.five_hour, now: now) {
                WindowLine(label: "5h", window: five, threshold: snap.threshold, now: now)
            }
            if let f = account.forecast(history: samples, threshold: snap.threshold, now: now) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 9, weight: .semibold))
                    Text("no ritmo atual, chega a \(Int(snap.threshold))% às \(timeText(f.fullAt.timeIntervalSince1970, now: now))"
                         + " · +\(Int(f.pointsPerHour.rounded())) pts/h")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.alerta)
            }
            if let seven = account.window(\.seven_day, now: now) {
                WindowLine(label: "7d", window: seven, threshold: snap.threshold, now: now)
            }
            if hasTrend(samples) {
                HStack(alignment: .bottom, spacing: 7) {
                    Text("24h")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .frame(width: 16, alignment: .leading)
                    Sparkline(samples: samples, now: now, tint: peak.map { usageTint($0, threshold: snap.threshold) } ?? .folga)
                    Text(agoText(account.usage?.updated_at, now: now))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 104, alignment: .trailing)
                }
            } else if account.loggedIn {
                Text(agoText(account.usage?.updated_at, now: now) + " · a linha de 24h aparece com 1h de histórico")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            if interactive, case .full = state {
                Button(action: onUnblock) {
                    CapsuleLabel(title: "Liberar agora", systemImage: "lock.open", style: .outline, fullWidth: true)
                }
                .buttonStyle(PressStyle())
                .help("Tira o bloqueio; use quando a cota voltou antes do previsto")
            }
        }
        .module()
    }
}

struct SummaryModule: View {
    let snap: Snapshot
    let now: Date

    var body: some View {
        let free = snap.freeCount(now: now)
        let total = snap.accounts.count
        HStack(spacing: 12) {
            Skewer(size: 46, colors: snap.accounts.map { $0.hasRoom(now: now) ? .folga : $0.loggedIn ? .cheia : .gray },
                   rod: Color.primary.opacity(0.45))
                .frame(width: 46, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(free) de \(total) contas com folga")
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .module()
    }

    private var subtitle: String {
        var parts: [String] = []
        if let order = snap.orderText {
            parts.append("ordem agora: \(order)")
        } else if let next = snap.next {
            parts.append("próxima: \(next.capitalized)")
        } else {
            parts.append("todas cheias")
        }
        if let first = snap.firstToFree(now: now) {
            parts.append("\(first.title) libera às \(timeText(first.free_at, now: now))")
        }
        return parts.joined(separator: " · ")
    }
}

struct SettingsModule: View {
    @ObservedObject var prefs: Prefs
    let snapshot: Snapshot?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Barra de menus")
            HStack {
                Spacer()
                Image(nsImage: MenuBarArt.image(snapshot, prefs: prefs, now: now, ink: .white))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.75)))
                Spacer()
            }
            toggle("Conta em uso e % ao lado do espeto", $prefs.showBlock)
            toggle("Mini barras coloridas, uma por conta", $prefs.showBars)
            Text("No espeto, pedaço cheio é conta com folga e vazado é conta cheia. Para mudar o ícone de lugar, segure ⌘ e arraste.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            section("Avisos")
            toggle("Avisar quando uma conta estiver para encher (~20 min), encher, liberar ou o claude-auto trocar",
                   $prefs.notify)
            Divider()
            section("Início")
            toggle("Abrir junto com o Mac", Binding(get: { prefs.launchAtLogin }, set: { prefs.setLaunchAtLogin($0) }))
                .disabled(!LoginItem.installed)
            if !LoginItem.installed {
                Text("Instale com rodizio/build.sh para abrir no login.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Divider()
            Text("Fila e limiar vêm do claude-auto (CLAUDE_AUTO_PROFILES e CLAUDE_AUTO_THRESHOLD).")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .module()
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { Text(title).font(.system(size: 12)) }
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

struct PanelView: View {
    @ObservedObject var store: Store
    @ObservedObject var prefs: Prefs
    @ObservedObject var ui: PanelUI
    var interactive = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                BrandMark(size: 26)
                Text("rodízio").font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                if interactive {
                    Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help("Atualizar")
                    Button { ui.showingSettings.toggle() } label: {
                        Image(systemName: ui.showingSettings ? "xmark.circle.fill" : "gearshape")
                    }
                    .buttonStyle(.borderless).help(ui.showingSettings ? "Voltar" : "Ajustes")
                }
            }
            .padding(.horizontal, 3)

            if ui.showingSettings {
                SettingsModule(prefs: prefs, snapshot: store.snapshot, now: store.now)
            } else if let snap = store.snapshot {
                SummaryModule(snap: snap, now: store.now)
                ForEach(snap.accounts) { a in
                    AccountModule(account: a, snap: snap, now: store.now, samples: store.history[a.name] ?? [],
                                  interactive: interactive) { store.unblock(a.name) }
                }
            } else {
                Text(store.error ?? "carregando…").font(.system(size: 11)).foregroundStyle(.secondary).module()
            }

            HStack {
                if let snap = store.snapshot {
                    Text("Passa a próxima. · " + (snap.usesResetOrder ? "zera antes, usa antes" : "ordem fixa")
                         + " · troca em \(Int(snap.threshold))%")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer()
                if interactive {
                    Button { NSApp.terminate(nil) } label: { CapsuleLabel(title: "Sair", style: .secondary) }
                        .buttonStyle(PressStyle())
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 3)
        }
        .padding(12)
        .frame(width: 344)
    }
}

// MARK: - Barra de menus e painel de vidro

private let panelRadius: CGFloat = 16

/// Máscara esticável com cantos arredondados para o vidro (cornerRadius não recorta o desfoque).
private func roundedMask(radius: CGFloat) -> NSImage {
    let edge = radius * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        return true
    }
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
}

/// Contorno fino dos painéis da Central de Controle; acompanha o tema.
final class PanelBorder: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = panelRadius
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); update() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); update() }

    private func update() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.borderColor = (dark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.1)).cgColor
    }
}

/// Painel que recebe cliques sem ativar o app.
final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class StatusController: NSObject, NSWindowDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = GlassPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let host: NSHostingView<PanelView>
    private let store: Store
    private let prefs: Prefs
    private let ui: PanelUI
    private var clickOutside: Any?
    private var bag = Set<AnyCancellable>()

    init(store: Store, prefs: Prefs) {
        self.store = store
        self.prefs = prefs
        let ui = PanelUI()
        self.ui = ui
        host = NSHostingView(rootView: PanelView(store: store, prefs: prefs, ui: ui))
        super.init()

        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let glass = NSVisualEffectView()
        glass.material = .popover
        glass.state = .active
        glass.blendingMode = .behindWindow
        glass.maskImage = roundedMask(radius: panelRadius)
        let border = PanelBorder()
        for view in [host, border] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            glass.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
                view.topAnchor.constraint(equalTo: glass.topAnchor),
                view.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            ])
        }
        panel.contentView = glass

        item.button?.target = self
        item.button?.action = #selector(toggle)

        // objectWillChange chega antes do valor mudar: redesenha no ciclo seguinte.
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshIcon(); self?.fit() }
        }.store(in: &bag)
        prefs.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshIcon() }
        }.store(in: &bag)
        ui.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.fit() }
        }.store(in: &bag)
        refreshIcon()
    }

    func refreshIcon() {
        guard let button = item.button else { return }
        button.image = MenuBarArt.image(store.snapshot, prefs: prefs, now: store.now)
        button.toolTip = MenuBarArt.tooltip(store.snapshot, now: store.now)
    }

    @objc private func toggle() { panel.isVisible ? close() : show() }

    /// Também chamado pelo clique no widget (rodizio://abrir).
    func show() {
        guard !panel.isVisible, let button = item.button, let buttonWindow = button.window else { return }
        store.refresh()
        let size = fittingSize()
        // Centralizado sob o ícone, sem sair da tela.
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = anchor.midX - size.width / 2
        x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: anchor.minY - size.height - 6, width: size.width, height: size.height), display: true)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        button.highlight(true)
        // Como os menus de Som e Wi-Fi: clique fora fecha.
        clickOutside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func close() {
        guard panel.isVisible else { return }
        if let clickOutside { NSEvent.removeMonitor(clickOutside) }
        clickOutside = nil
        item.button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.1; panel.animator().alphaValue = 0 }) { [panel] in
            panel.orderOut(nil)
        }
        ui.showingSettings = false
    }

    private func fittingSize() -> NSSize {
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Conteúdo mudou de altura (Ajustes, conta cheia ganhou botão): mantém o topo no lugar.
    private func fit() {
        guard panel.isVisible else { return }
        let size = fittingSize()
        let frame = panel.frame
        guard abs(frame.height - size.height) > 0.5 else { return }
        panel.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: frame.width, height: size.height), display: true)
        panel.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) { close() }
}

// MARK: - Prévias (--snapshot, --widgets, --icon)

@MainActor
enum Previews {
    static func write(_ view: some View, to path: String, scale: CGFloat) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("falha ao renderizar \(path)\n".utf8))
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    /// Painel (escuro, Ajustes e claro) e a barra de menus nas duas variações.
    static func panels(to path: String) {
        let store = Store()
        store.refreshNow()
        // Ajustes só em memória: a prévia não pode mudar a barra de verdade.
        let prefs = Prefs(persist: false)
        prefs.showBars = false
        prefs.showBlock = true
        let settings = PanelUI()
        settings.showingSettings = true
        let bars = Prefs(persist: false)
        bars.showBars = true
        bars.showBlock = true

        func bar(_ p: Prefs, dark: Bool) -> some View {
            Image(nsImage: MenuBarArt.image(store.snapshot, prefs: p, now: store.now, ink: dark ? .white : .black))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(dark ? Color.black.opacity(0.85) : Color.white.opacity(0.9))
        }
        func chrome(_ v: some View, dark: Bool) -> some View {
            v.background(RoundedRectangle(cornerRadius: panelRadius).fill(dark ? Color(hex: 0x262220) : Color(hex: 0xF3F1EF)))
                .environment(\.colorScheme, dark ? .dark : .light)
        }
        let view = VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                bar(prefs, dark: true)
                bar(prefs, dark: false)
                bar(bars, dark: true)
                bar(bars, dark: false)
            }
            HStack(alignment: .top, spacing: 16) {
                chrome(PanelView(store: store, prefs: prefs, ui: PanelUI(), interactive: false), dark: true)
                chrome(PanelView(store: store, prefs: prefs, ui: settings, interactive: false), dark: true)
                chrome(PanelView(store: store, prefs: prefs, ui: PanelUI(), interactive: false), dark: false)
            }
        }
        .padding(20)
        .background(Color(hex: 0x6B7280))
        write(view, to: path, scale: 2)
    }

    /// Widgets pequeno, médio e grande, nos temas escuro e claro, com os dados de agora.
    static func widgets(to path: String) {
        let store = Store()
        store.refreshNow()
        guard let snap = store.snapshot else {
            FileHandle.standardError.write(Data("sem dados do claude-auto\n".utf8))
            exit(1)
        }
        let payload = WidgetPayload(snapshot: snap, history: store.history)
        let now = store.now
        // Tamanhos dos widgets do macOS, com a margem que o sistema põe em volta.
        func tile(_ v: some View, _ w: CGFloat, _ h: CGFloat, dark: Bool) -> some View {
            v.padding(16)
                .frame(width: w, height: h)
                .background(WidgetBackground())
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, dark ? .dark : .light)
        }
        let view = HStack(alignment: .top, spacing: 18) {
            ForEach([true, false], id: \.self) { dark in
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        tile(SmallWidgetView(payload: payload, now: now), 170, 170, dark: dark)
                        tile(MediumWidgetView(payload: payload, now: now), 364, 170, dark: dark)
                    }
                    tile(LargeWidgetView(payload: payload, now: now), 364, 382, dark: dark)
                }
            }
        }
        .padding(24)
        .background(Color(hex: 0x6B7280))
        write(view, to: path, scale: 2)
    }

    /// Ícone do app em 1024 px, já com a margem e a sombra do grid do macOS.
    static func icon(to path: String) {
        let view = BrandMark(size: 824)
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            .frame(width: 1024, height: 1024)
        write(view, to: path, scale: 1)
    }
}

// MARK: - App

@main @MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: StatusController?

    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Previews.panels(to: args[i + 1])
            exit(0)
        }
        if let i = args.firstIndex(of: "--widgets"), i + 1 < args.count {
            Previews.widgets(to: args[i + 1])
            exit(0)
        }
        if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
            Previews.icon(to: args[i + 1])
            exit(0)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = Store.shared
        store.onUpdate = { old, oldNow, new, now in
            Notifier.diff(old: old, oldNow: oldNow, new: new, now: now)
            Notifier.forecast(new, history: store.history, now: now)
        }
        status = StatusController(store: store, prefs: .shared)
        store.start()
        if Prefs.shared.notify { Notifier.requestAuthorization() }
    }

    /// Clique no widget (rodizio://abrir): abre o painel.
    func application(_ application: NSApplication, open urls: [URL]) {
        status?.show()
    }
}
