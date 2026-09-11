import SwiftUI

struct ThreadView: View {
    let model: ChatModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(model.messages) { message in
                        MessageView(message: message, model: model)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.revision) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

struct MessageView: View {
    let message: Message
    let model: ChatModel

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.userText)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.text)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 22)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.bubble))
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .assistant:
            VStack(alignment: .leading, spacing: 16) {
                if let reasoning = message.reasoning {
                    ReasoningCard(reasoning: reasoning) { model.toggleReasoning(message.id) }
                }
                if message.visibleWords > 0 {
                    StreamedText(segments: message.segments, visible: message.visibleWords)
                }
                if let card = message.card {
                    cardView(card)
                }
                if let categoryID = message.roundUpCategory {
                    RoundUpAside(
                        category: SpendData.category(categoryID),
                        onLearn: { model.explainRoundUp() },
                        onDismiss: { model.dismissRoundUp(message.id) }
                    )
                }
                if message.showActions {
                    ActionRow()
                }
                if !message.followUps.isEmpty {
                    FollowUpChips(items: message.followUps) { model.perform($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func cardView(_ card: CardKind) -> some View {
        switch card {
        case .insight:
            InsightCard { model.tapCategory($0) }
        case .drill(let id):
            DrillCard(category: SpendData.category(id))
        case .receipt:
            ReceiptCard()
        case .monthlyConfirm:
            ConfirmCard(title: "Monthly recap is on", subtitle: "Next: Thu 1 Oct, 9:00am · Change anytime in Settings")
        case .roundUpCTA:
            CTAButton(title: "Turn on Round-Up") { model.turnOnRoundUp(message.id) }
        case .roundUpConfirm:
            ConfirmCard(title: "Round-Up is on", subtitle: "Your first round-up lands with your next card payment.")
        }
    }
}

// MARK: - Streamed assistant text

struct StreamedText: View {
    let segments: [TextSegment]
    let visible: Int

    var body: some View {
        rendered
            .font(.system(size: 18.5))
            .foregroundStyle(Color(hex: 0xEEF1EF))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Reveals `visible` words across the segments, keeping bold runs intact.
    private var rendered: Text {
        var remaining = visible
        var output = Text("")
        for segment in segments {
            let parts = segment.text.components(separatedBy: " ")
            var kept: [String] = []
            var stop = false
            for part in parts {
                if part.isEmpty { kept.append(part); continue }
                if remaining == 0 { stop = true; break }
                kept.append(part)
                remaining -= 1
            }
            let piece = Text(kept.joined(separator: " "))
            output = output + (segment.bold ? piece.fontWeight(.semibold).foregroundColor(.white) : piece)
            if stop { break }
        }
        return output
    }
}

// MARK: - Reasoning

struct ReasoningCard: View {
    let reasoning: Reasoning
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack {
                    if reasoning.finished {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.green)
                            Text("\(reasoning.steps.count) check\(reasoning.steps.count == 1 ? "" : "s") complete")
                                .font(.system(size: 17.5))
                                .foregroundStyle(Color(hex: 0xC9D0CD))
                        }
                    } else {
                        Text(reasoning.title)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color(hex: 0xE8EBEA))
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        if !reasoning.finished {
                            Text("\(reasoning.completed) step\(reasoning.completed == 1 ? "" : "s") so far")
                                .font(.system(size: 17))
                                .foregroundStyle(Color(hex: 0xB3BAB7))
                                .contentTransition(.numericText())
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xAAB1AE))
                            .rotationEffect(.degrees(reasoning.expanded ? 180 : 0))
                    }
                }
                .padding(.vertical, 17)
                .padding(.horizontal, 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if reasoning.expanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().overlay(Theme.line)
                    ForEach(0..<reasoning.revealed, id: \.self) { index in
                        HStack(spacing: 16) {
                            ZStack {
                                if index < reasoning.completed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.green)
                                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                                } else {
                                    ProgressView()
                                        .tint(Color(hex: 0xCFD5D2))
                                        .controlSize(.small)
                                }
                            }
                            .frame(width: 24, height: 24)
                            Text(reasoning.steps[index])
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: 0xD8DDDA))
                        }
                        .padding(.vertical, 12)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Action row and follow-ups

struct ActionRow: View {
    @State private var vote = 0

    var body: some View {
        HStack(spacing: 26) {
            icon("doc.on.doc") { }
            icon("speaker.wave.2") { }
            icon("hand.thumbsup", active: vote == 1) { vote = vote == 1 ? 0 : 1 }
            icon("hand.thumbsdown", active: vote == -1) { vote = vote == -1 ? 0 : -1 }
            icon("square.and.arrow.up") { }
        }
        .padding(.leading, 2)
    }

    private func icon(_ name: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 19))
                .foregroundStyle(active ? Theme.green : Color(hex: 0xD7DBD9))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(PressStyle())
    }
}

struct FollowUpChips: View {
    let items: [FollowUp]
    let onTap: (FollowUp) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button { onTap(item) } label: {
                        Text(item.label)
                            .font(.system(size: 15.5))
                            .foregroundStyle(Color(hex: 0xDFE4E1))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(Capsule().fill(Color.white.opacity(0.03)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }
}
