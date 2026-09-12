import SwiftUI

// MARK: - Shared pieces

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.4)
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
        let isNew = prev == 0
        let label = isNew ? "new" : (direction == .flat ? "same" : "\(direction.arrow) \(abs(percent))%")
        let tint = isNew ? Theme.lime : color(for: direction)
        Text(label)
            .font(.system(size: 14, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.vertical, compact ? 0 : 5)
            .padding(.horizontal, compact ? 0 : 11)
            .background {
                if !compact {
                    Capsule().fill(tint.opacity(0.12))
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
    var compact = false      // rail: fixed top four, no expander
    var fillHeight = false   // rail: stretch the card to the rail height
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
            if showAll || compact {
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
        .frame(maxHeight: fillHeight ? .infinity : nil, alignment: .top)
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
        let top = category.lines[0]
        let maxAmount = category.lines.map(\.amount).max() ?? 1
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
                    value: top.label,
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
                ForEach(category.lines) { merchant in
                    VStack(spacing: 7) {
                        HStack {
                            Text(merchant.label)
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
                .tracking(0.3)
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
    let scope: RoundUpScope
    let onLearn: () -> Void
    let onDismiss: () -> Void

    private var copy: Text {
        switch scope {
        case .category(let id):
            let category = SpendData.category(id)
            return Text("Your \(category.count) \(category.name.lowercased()) payments left ")
                + Text(aed(category.spare)).fontWeight(.semibold).foregroundColor(.white)
                + Text(" in spare change. Round-Up Savings would have set that aside on its own, about ")
                + Text(aed(SpendData.spareTotal)).fontWeight(.semibold).foregroundColor(.white)
                + Text(" a month across your card.")
        case .month:
            let yearly = Int((SpendData.spareTotal * 12).rounded())
            return Text("Your \(SpendData.cardCount) card payments in August left ")
                + Text(aed(SpendData.spareTotal)).fontWeight(.semibold).foregroundColor(.white)
                + Text(" in spare change. Round-Up Savings would have set that aside on its own, roughly ")
                + Text(aed(yearly)).fontWeight(.semibold).foregroundColor(.white)
                + Text(" a year, without changing anything you do.")
        }
    }

    /// Title, copy and the two text buttons; shared by both layouts.
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Put your spare change in a jar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            copy
                .font(.system(size: 14.5))
                .foregroundStyle(Color(hex: 0xC9D0CD))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                Button(action: onLearn) {
                    Text("See how it works")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                }
                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text3)
                }
            }
            .buttonStyle(PressStyle())
            .padding(.top, 6)
        }
    }

    var body: some View {
        Group {
            if let artwork = UIImage(named: "RoundUpCallout") {
                // Designed artwork (jar + background, no text) with live text over the right side.
                HStack(spacing: 0) {
                    Color.clear.frame(width: 128)
                    textBlock
                        .padding(.vertical, 18)
                        .padding(.trailing, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            } else {
                // Fallback until the artwork is added to Assets.xcassets/RoundUpCallout.
                HStack(alignment: .top, spacing: 14) {
                    JarIcon()
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.lime.opacity(0.14)))
                    textBlock
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
            }
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

/// SF Symbols has no jar, so this is a small one drawn with shapes: lid, neck, body, two coins.
struct JarIcon: View {
    var body: some View {
        VStack(spacing: 1.5) {
            Capsule()
                .fill(Theme.lime)
                .frame(width: 13, height: 3)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Theme.lime.opacity(0.75))
                .frame(width: 9, height: 2)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.lime, lineWidth: 1.6)
                    .frame(width: 14, height: 12)
                HStack(spacing: 1.5) {
                    Circle().fill(Theme.lime).frame(width: 4, height: 4)
                    Circle().fill(Theme.lime).frame(width: 4, height: 4)
                }
                .padding(.bottom, 2.5)
            }
        }
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
    var icon = "checkmark"
    let title: String
    let subtitle: String
    var linkTitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.green)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.green.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let linkTitle {
                    Button { } label: {
                        Text(linkTitle)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Theme.lime)
                            .underline(true, color: Theme.lime.opacity(0.5))
                    }
                    .buttonStyle(PressStyle())
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(radius: 20)
    }
}
