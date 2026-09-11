import SwiftUI

// MARK: - Shared pieces

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Theme.text3)
    }
}

struct BigAmount: View {
    let value: Int
    init(_ value: Int) { self.value = value }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("AED")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text(value.formatted(.number))
                .font(.system(size: 38, weight: .bold))
                .tracking(-1.4)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
    }
}

struct DeltaPill: View {
    let now: Int
    let prev: Int
    var compact = false

    var body: some View {
        let percent = percentChange(now, prev)
        let direction = Direction(percent: percent)
        let label = direction == .flat ? "same" : "\(abs(percent))%"
        Text("\(direction.arrow) \(label)")
            .font(.system(size: 14, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color(for: direction))
            .padding(.vertical, compact ? 0 : 5)
            .padding(.horizontal, compact ? 0 : 11)
            .background {
                if !compact {
                    Capsule().fill(color(for: direction).opacity(0.12))
                }
            }
    }

    private func color(for direction: Direction) -> Color {
        switch direction {
        case .down: return Theme.green
        case .up: return Theme.amber
        case .flat: return Theme.text2
        }
    }
}

// MARK: - Insight card (primary response)

struct InsightCard: View {
    let onTap: (SpendCategory) -> Void
    @State private var showAll = false

    private var categories: [SpendCategory] { SpendData.categories }
    private var visible: [SpendCategory] { showAll ? categories : Array(categories.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("August spending")
                Spacer()
                DeltaPill(now: SpendData.total, prev: SpendData.prevTotal)
            }
            BigAmount(SpendData.total)
                .padding(.top, 10)
            Text("July was \(aed(SpendData.prevTotal)) · \(SpendData.paymentCount) payments")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)
            StackedBar(categories: categories)
                .padding(.top, 18)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(visible) { category in
                    Divider().overlay(Theme.line)
                    CategoryRow(category: category) { onTap(category) }
                }
            }
            .padding(.top, 8)
            if showAll {
                Color.clear.frame(height: 8)
            } else {
                Divider().overlay(Theme.line)
                Button {
                    withAnimation(.spring(duration: 0.4)) { showAll = true }
                } label: {
                    Text("Show all \(categories.count) categories")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .cardBackground(radius: 26)
    }
}

struct StackedBar: View {
    let categories: [SpendCategory]
    @State private var grown = false

    var body: some View {
        let total = Double(categories.reduce(0) { $0 + $1.now })
        GeometryReader { geo in
            let gaps = CGFloat(categories.count - 1) * 3
            HStack(spacing: 3) {
                ForEach(categories) { category in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.ramp[category.colorIndex])
                        .frame(width: max(4, (geo.size.width - gaps) * CGFloat(Double(category.now) / total)))
                }
            }
            .scaleEffect(x: grown ? 1 : 0.001, anchor: .leading)
        }
        .frame(height: 14)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.spring(duration: 0.8)) { grown = true }
        }
    }
}

struct CategoryRow: View {
    let category: SpendCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.ramp[category.colorIndex])
                    .frame(width: 10, height: 10)
                Text(category.name)
                    .font(.system(size: 17))
                    .foregroundStyle(Color(hex: 0xE6EAE8))
                Spacer()
                Text(category.now.formatted(.number))
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0xF4F6F5))
                DeltaPill(now: category.now, prev: category.prev, compact: true)
                    .frame(width: 58, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Drill-down card

struct DrillCard: View {
    let category: SpendCategory

    var body: some View {
        let top = category.merchants[0]
        let maxAmount = category.merchants.map(\.amount).max() ?? 1
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("\(category.name) · August")
                Spacer()
                DeltaPill(now: category.now, prev: category.prev)
            }
            BigAmount(category.now)
                .padding(.top, 10)
            Text("July was \(aed(category.prev)) · \(category.count) payments")
                .font(.system(size: 15))
                .foregroundStyle(Theme.text2)
                .padding(.top, 8)
            HStack(spacing: 12) {
                StatTile(
                    label: "Top merchant",
                    value: top.name,
                    detail: top.detail.isEmpty ? aed(top.amount) : "\(aed(top.amount)) · \(top.detail)"
                )
                StatTile(
                    label: "Largest payment",
                    value: aed(category.largest.amount),
                    detail: "\(category.largest.merchant) · \(category.largest.date)"
                )
            }
            .padding(.top, 18)
            VStack(spacing: 12) {
                ForEach(category.merchants) { merchant in
                    VStack(spacing: 7) {
                        HStack {
                            Text(merchant.name)
                                .font(.system(size: 15.5))
                                .foregroundStyle(Color(hex: 0xE3E7E5))
                            Spacer()
                            Text(aed(merchant.amount))
                                .font(.system(size: 15.5))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text2)
                        }
                        MerchantBar(
                            fraction: Double(merchant.amount) / Double(maxAmount),
                            color: Theme.ramp[category.colorIndex]
                        )
                    }
                }
            }
            .padding(.top, 18)
            Text(category.pattern)
                .font(.system(size: 15.5))
                .foregroundStyle(Theme.text2)
                .lineSpacing(3)
                .padding(.top, 16)
        }
        .padding(20)
        .cardBackground(radius: 26)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Theme.text3)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 6)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text2)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
    }
}

struct MerchantBar: View {
    let fraction: Double
    let color: Color
    @State private var grown = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(fraction) * (grown ? 1 : 0))
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.spring(duration: 0.8)) { grown = true }
        }
    }
}

// MARK: - Round-Up aside

struct RoundUpAside: View {
    let category: SpendCategory
    let onLearn: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.lime)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.lime.opacity(0.14)))
            VStack(alignment: .leading, spacing: 12) {
                (Text("Your \(category.count) \(category.name.lowercased()) payments left ")
                    + Text(aed(category.spare)).fontWeight(.semibold).foregroundColor(.white)
                    + Text(" in spare change. Round-Up Savings would have set that aside on its own, about ")
                    + Text(aed(SpendData.spareTotal)).fontWeight(.semibold).foregroundColor(.white)
                    + Text(" a month across your card."))
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: 0xDFE4E1))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 20) {
                    Button(action: onLearn) {
                        Text("See how it works")
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Theme.lime)
                    }
                    Button(action: onDismiss) {
                        Text("Not now")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                }
                .buttonStyle(PressStyle())
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.lime.opacity(0.07), Theme.green.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.lime.opacity(0.12), lineWidth: 1))
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

// MARK: - Small cards

struct CTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 16.5, weight: .semibold))
            }
            .foregroundStyle(Color(hex: 0x0B1409))
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .background(Capsule().fill(Theme.lime))
        }
        .buttonStyle(PressStyle())
    }
}

struct ConfirmCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.green)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.green.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(radius: 20)
    }
}

struct ReceiptCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("noon")
                .font(.system(size: 16, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color(hex: 0x1A1A1A))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF6E04A)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Noon")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Fri 14 Aug · Shopping · Mal card ending 4021")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            Text("AED 899")
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.5)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .cardBackground(radius: 20)
    }
}
