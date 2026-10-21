// WidgetViews.swift — os widgets do Rodízio (pequeno, médio e grande) como
// views comuns, sem WidgetKit: a extensão usa estas views, e o app também,
// para as prévias (`Rodizio --widgets prévia.png`).

import SwiftUI

/// Fundo do widget: carvão no escuro, papel no claro.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            LinearGradient(colors: [Color(hex: 0x2B221D), .carvao], startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: [Color(hex: 0xFBF8F5), Color(hex: 0xF0EAE4)], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct WidgetHeader: View {
    var body: some View {
        HStack(spacing: 5) {
            Skewer(size: 22, rod: Color.primary.opacity(0.5)).frame(width: 22, height: 14)
            Text("rodízio").font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }
}

/// "3/4 com folga", em verde; vermelho quando todas estão cheias.
struct FreeCount: View {
    let snap: Snapshot
    let now: Date
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(snap.freeCount(now: now))")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(snap.next == nil ? Color.cheia : Color.folga)
                Text("/\(snap.accounts.count)")
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(snap.next == nil ? "todas cheias" : "contas com folga")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// Próxima da fila e, se houver, a conta cheia que libera primeiro.
func queueLine(_ snap: Snapshot, now: Date, short: Bool = false) -> String {
    var parts: [String] = []
    if let next = snap.next { parts.append("próxima: \(next.capitalized)") }
    if let first = snap.firstToFree(now: now), !short || snap.next == nil {
        parts.append("\(first.title) libera às \(timeText(first.free_at, now: now))")
    }
    return parts.isEmpty ? "todas cheias" : parts.joined(separator: " · ")
}

func accountPct(_ a: Account, now: Date) -> Double {
    a.isFull(now: now) ? 100 : (a.peak(now: now) ?? 0)
}

/// Colunas verticais, uma por conta, com a inicial embaixo.
struct AccountColumns: View {
    let snap: Snapshot
    let now: Date

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(snap.accounts) { a in
                let pct = accountPct(a, now: now)
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color.primary.opacity(0.12))
                        Capsule()
                            .fill(a.loggedIn ? usageTint(pct, threshold: snap.threshold) : .gray)
                            .frame(height: max(3, 26 * min(pct, 100) / 100))
                    }
                    .frame(width: 9, height: 26)
                    Text(a.initial)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(a.name == snap.next ? AnyShapeStyle(Color.brasa) : AnyShapeStyle(.secondary))
                }
            }
        }
    }
}

struct Avatar: View {
    let account: Account
    let state: AccountState
    let size: CGFloat

    var body: some View {
        Text(account.initial)
            .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(stateColor(state).gradient))
    }
}

struct NextTag: View {
    var body: some View {
        Text("próxima")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Color.brasa)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(Color.brasa.opacity(0.16)))
    }
}

/// Valor à direita da conta: o % de uso, ou o horário em que a cheia libera.
func rightValue(_ a: Account, snap: Snapshot, now: Date) -> (text: String, color: Color) {
    if a.isFull(now: now) { return ("até \(timeText(a.free_at, now: now))", .cheia) }
    guard let peak = a.peak(now: now) else { return ("—", .secondary) }
    return ("\(Int(peak))%", usageTint(peak, threshold: snap.threshold))
}

struct CompactRow: View {
    let account: Account
    let snap: Snapshot
    let now: Date

    var body: some View {
        let state = account.state(now: now)
        let value = rightValue(account, snap: snap, now: now)
        HStack(spacing: 7) {
            Avatar(account: account, state: state, size: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(account.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    if account.name == snap.next { NextTag() }
                    Spacer(minLength: 2)
                    Text(value.text)
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(value.color)
                }
                Bar(fraction: accountPct(account, now: now) / 100,
                    tint: account.loggedIn ? usageTint(accountPct(account, now: now), threshold: snap.threshold) : .gray)
            }
        }
    }
}

struct LargeRow: View {
    let account: Account
    let snap: Snapshot
    let now: Date
    let samples: [Sample]

    var body: some View {
        let state = account.state(now: now)
        let value = rightValue(account, snap: snap, now: now)
        let pct = accountPct(account, now: now)
        let tint = account.loggedIn ? usageTint(pct, threshold: snap.threshold) : Color.gray
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Avatar(account: account, state: state, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(account.title).font(.system(size: 12, weight: .semibold))
                        if account.name == snap.next { NextTag() }
                    }
                    Text(account.account?.email ?? stateText(state, now: now))
                        .font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(value.text)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(value.color)
                    Text(stateText(state, now: now))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(stateColor(state) == .gray ? AnyShapeStyle(.secondary) : AnyShapeStyle(stateColor(state)))
                }
            }
            HStack(spacing: 6) {
                Bar(fraction: pct / 100, tint: tint)
                if hasTrend(samples) {
                    Sparkline(samples: samples, now: now, tint: tint).frame(width: 56)
                }
                Text(account.window(\.five_hour, now: now).map { "zera \(timeText($0.resets_at, now: now))" } ?? "")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

struct SmallWidgetView: View {
    let payload: WidgetPayload
    let now: Date

    var body: some View {
        let snap = payload.snapshot
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader()
            Spacer(minLength: 4)
            FreeCount(snap: snap, now: now)
            Spacer(minLength: 6)
            AccountColumns(snap: snap, now: now)
            Text(queueLine(snap, now: now, short: true))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumWidgetView: View {
    let payload: WidgetPayload
    let now: Date

    var body: some View {
        let snap = payload.snapshot
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader()
                Spacer(minLength: 4)
                FreeCount(snap: snap, now: now)
                Spacer(minLength: 4)
                Text(queueLine(snap, now: now))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 104, alignment: .leading)
            VStack(spacing: 7) {
                ForEach(snap.accounts) { CompactRow(account: $0, snap: snap, now: now) }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}

struct LargeWidgetView: View {
    let payload: WidgetPayload
    let now: Date

    var body: some View {
        let snap = payload.snapshot
        let free = snap.freeCount(now: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                WidgetHeader()
                Spacer()
                Text("\(free) de \(snap.accounts.count) com folga")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(free > 0 ? Color.folga : Color.cheia)
            }
            Text(queueLine(snap, now: now))
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            ForEach(snap.accounts) { a in
                LargeRow(account: a, snap: snap, now: now, samples: payload.history[a.name] ?? [])
            }
            Spacer(minLength: 0)
            Text("Passa a próxima. · fila " + snap.accounts.map(\.initial).joined(separator: "→")
                 + " · troca em \(Int(snap.threshold))%")
                .font(.system(size: 9.5)).foregroundStyle(.tertiary)
        }
    }
}

struct EmptyWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader()
            Spacer(minLength: 0)
            Text("Abra o Rodízio para ver as contas.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension WidgetPayload {
    /// Dados de exemplo para a galeria de widgets, antes do primeiro dado real.
    static var preview: WidgetPayload {
        let t = Date().timeIntervalSince1970
        func account(_ name: String, _ pct: Double, full: Bool = false, inUse: Int = 0) -> Account {
            Account(name: name, exists: true, in_use: inUse, free_at: full ? t + 5400 : 0,
                    usage: Usage(rate_limits: RateLimits(five_hour: UsageWindow(used_percentage: pct, resets_at: t + 7200),
                                                         seven_day: nil), updated_at: t),
                    account: AccountInfo(email: "\(name)@exemplo.com", name: nil))
        }
        let snapshot = Snapshot(threshold: 95, next: "ranielli", accounts: [
            account("pessoal", 100, full: true), account("ranielli", 38, inUse: 1),
            account("contato", 72), account("orca", 12),
        ])
        return WidgetPayload(snapshot: snapshot, history: [:])
    }
}
