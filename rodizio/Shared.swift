// Shared.swift — o que o app Rodízio e o widget usam juntos: o modelo do
// `claude-auto status --json`, o arquivo que o app grava para o widget, a
// paleta e as peças de desenho (espeto, barra, linha de 24 h).

import AppKit
import SwiftUI

// MARK: - Modelo (espelha `claude-auto status --json`)

struct UsageWindow: Codable {
    let used_percentage: Double
    let resets_at: Double
}

struct RateLimits: Codable {
    let five_hour: UsageWindow?
    let seven_day: UsageWindow?
}

struct Usage: Codable {
    let rate_limits: RateLimits?
    let updated_at: Double?
}

struct AccountInfo: Codable {
    let email: String?
    let name: String?
}

struct Account: Codable, Identifiable {
    let name: String
    let exists: Bool
    let in_use: Int
    let free_at: Double
    let usage: Usage?
    let account: AccountInfo?

    var id: String { name }
    var title: String { name.prefix(1).uppercased() + name.dropFirst() }
    var initial: String { String(name.prefix(1)).uppercased() }
    var loggedIn: Bool { exists && account?.email != nil }

    /// Janela só conta enquanto o reset não passou (depois disso zerou).
    func window(_ kp: KeyPath<RateLimits, UsageWindow?>, now: Date) -> UsageWindow? {
        guard let w = usage?.rate_limits?[keyPath: kp], w.resets_at > now.timeIntervalSince1970 else { return nil }
        return w
    }

    /// Uso da janela mais cheia (5h ou 7d).
    func peak(now: Date) -> Double? {
        [window(\.five_hour, now: now), window(\.seven_day, now: now)].compactMap { $0?.used_percentage }.max()
    }

    func isFull(now: Date) -> Bool { free_at > now.timeIntervalSince1970 }
    func hasRoom(now: Date) -> Bool { loggedIn && !isFull(now: now) }

    /// A statusline gravou há pouco: alguma sessão (com ou sem wrapper) está usando.
    func recentlyActive(now: Date) -> Bool {
        guard let t = usage?.updated_at else { return false }
        return now.timeIntervalSince1970 - t < 300
    }

    func state(now: Date) -> AccountState {
        if !exists { return .missing }
        if account?.email == nil { return .loggedOut }
        if isFull(now: now) { return .full(until: free_at) }
        if in_use > 0 { return .inUse(in_use) }
        if recentlyActive(now: now) { return .active }
        return .free
    }
}

enum AccountState: Equatable {
    case missing, loggedOut, full(until: Double), inUse(Int), active, free
}

struct Snapshot: Codable {
    let threshold: Double
    let next: String?
    let accounts: [Account]

    func freeCount(now: Date) -> Int { accounts.filter { $0.hasRoom(now: now) }.count }

    /// Conta do bloco da barra: a que está em uso; senão a que usou por
    /// último; senão a próxima da fila.
    func focus(now: Date) -> Account? {
        if let a = accounts.first(where: { $0.in_use > 0 }) { return a }
        let recent = accounts.filter { $0.recentlyActive(now: now) }
            .max { ($0.usage?.updated_at ?? 0) < ($1.usage?.updated_at ?? 0) }
        return recent ?? accounts.first { $0.name == next }
    }

    /// Conta cheia que libera primeiro.
    func firstToFree(now: Date) -> Account? {
        accounts.filter { $0.loggedIn && $0.isFull(now: now) }.min { $0.free_at < $1.free_at }
    }
}

/// Ponto do histórico: uso da janela de 5h num instante.
struct Sample: Codable {
    let t: Double
    let p: Double
}

// MARK: - Arquivo do widget

/// O que o app grava e o widget lê: o retrato do claude-auto e o histórico.
/// Fica em ~/Library/Application Support/Rodizio, a única pasta que o sandbox
/// do widget pode ler (exceção no entitlement).
struct WidgetPayload: Codable {
    let snapshot: Snapshot
    let history: [String: [Sample]]

    static var url: URL {
        realHome.appendingPathComponent("Library/Application Support/Rodizio/widget.json")
    }

    static func load() -> WidgetPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}

/// Home de verdade: dentro do sandbox, o home do processo é o contêiner.
var realHome: URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: dir))
    }
    return FileManager.default.homeDirectoryForCurrentUser
}

// MARK: - Marca

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Brasa: a cor do Claude, das ações e da marca.
    static let brasa = Color(hex: 0xD97757)
    /// Brasa mais clara, para texto e contorno no modo escuro.
    static let brasaClara = Color(hex: 0xF0A27F)
    static let carvao = Color(hex: 0x1C1613)
    /// Conta com folga.
    static let folga = Color(hex: 0x2EC4A6)
    static let alerta = Color(hex: 0xF2B544)
    static let cheia = Color(hex: 0xE5484D)
}

func usageTint(_ pct: Double, threshold: Double) -> Color {
    pct >= threshold ? .cheia : pct >= 70 ? .alerta : .folga
}

let ptBR = Locale(identifier: "pt_BR")

func timeText(_ epoch: Double, now: Date) -> String {
    let date = Date(timeIntervalSince1970: epoch)
    let f = DateFormatter()
    f.locale = ptBR
    f.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"
    return f.string(from: date)
}

func agoText(_ epoch: Double?, now: Date) -> String {
    guard let epoch else { return "sem uso registrado" }
    let min = Int((now.timeIntervalSince1970 - epoch) / 60)
    if min < 1 { return "usada agora" }
    if min < 60 { return "usada há \(min) min" }
    if min < 60 * 48 { return "usada há \(min / 60) h" }
    return "usada há \(min / 1440) dias"
}

func stateText(_ s: AccountState, now: Date) -> String {
    switch s {
    case .missing: "sem perfil"
    case .loggedOut: "sem login"
    case .full(let until): "cheia até \(timeText(until, now: now))"
    case .inUse(let n): n > 1 ? "em uso ×\(n)" : "em uso"
    case .active: "ativa"
    case .free: "livre"
    }
}

func stateColor(_ s: AccountState) -> Color {
    switch s {
    case .missing, .loggedOut: .gray
    case .full: .cheia
    case .inUse, .active: .brasa
    case .free: .folga
    }
}

/// O espeto da marca: quatro pedaços, um por conta, nas cores do uso.
struct Skewer: View {
    let size: CGFloat
    var colors: [Color] = [.folga, .alerta, .brasa, .cheia]
    /// Palito: creme sobre o carvão do ícone; nos painéis, a cor do texto.
    var rod = Color(hex: 0xF1E4D3)

    var body: some View {
        ZStack {
            Capsule().fill(rod).frame(width: size * 0.84, height: size * 0.032)
            Circle().stroke(rod, lineWidth: size * 0.026)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: -size * 0.47)
            HStack(spacing: size * 0.035) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                        .fill(c)
                        .frame(width: size * 0.13, height: size * 0.22)
                        .shadow(color: .black.opacity(0.25), radius: size * 0.012, y: size * 0.01)
                }
            }
            .offset(x: size * 0.05)
        }
        .rotationEffect(.degrees(-28))
    }
}

struct Bar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint).frame(width: max(g.size.width * min(fraction, 1), 5))
            }
        }
        .frame(height: 6)
    }
}

/// A linha de 24 h só aparece com pelo menos 1 h de histórico; antes disso
/// seria um risco solto na ponta direita.
func hasTrend(_ samples: [Sample]) -> Bool {
    guard let first = samples.first, let last = samples.last else { return false }
    return samples.count >= 2 && last.t - first.t >= 3600
}

/// Uso da janela de 5h ao longo do histórico que existe, até 24 h: com poucas
/// horas gravadas, o eixo cobre só elas e a linha ocupa a largura toda.
struct Sparkline: View {
    let samples: [Sample]
    let now: Date
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let end = now.timeIntervalSince1970
            let start = max(end - 86_400, samples.first?.t ?? end - 86_400)
            let span = max(end - start, 1)
            let pts = samples.map { s in
                CGPoint(x: max(0, (s.t - start) / span) * g.size.width,
                        y: g.size.height - CGFloat(min(s.p, 100) / 100) * g.size.height)
            } + [CGPoint(x: g.size.width, y: g.size.height - CGFloat(min(samples.last?.p ?? 0, 100) / 100) * g.size.height)]
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: pts[0].x, y: g.size.height))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: pts[0])
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            }
        }
        .frame(height: 16)
    }
}
