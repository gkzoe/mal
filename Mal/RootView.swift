import SwiftUI

struct RootView: View {
    @State private var model = ChatModel()
    @FocusState private var composerFocused: Bool

    var body: some View {
        ZStack {
            Backdrop(active: model.inChat, thinking: model.thinking)
            VStack(spacing: 0) {
                TopBar(model: model)
                ZStack {
                    if model.inChat {
                        ThreadView(model: model)
                            .transition(.opacity)
                    } else {
                        HomeView(model: model)
                            .transition(.opacity.combined(with: .offset(y: -12)))
                    }
                }
                .animation(.easeOut(duration: 0.35), value: model.inChat)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Composer(model: model, focused: $composerFocused)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Background

struct Backdrop: View {
    let active: Bool
    let thinking: Bool

    private var glow: Double { thinking ? 0.62 : (active ? 0.45 : 0.28) }

    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Color(hex: 0x125C48).opacity(glow), .clear],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 460
            )
            .animation(.easeInOut(duration: 1.2), value: glow)
            GeometryReader { geo in
                ZStack {
                    Text("مال")
                        .font(.system(size: 380, weight: .bold, design: .serif))
                        .fixedSize()
                        .rotationEffect(.degrees(-8))
                        .position(x: geo.size.width + 20, y: 220)
                    Text("مال")
                        .font(.system(size: 340, weight: .bold, design: .serif))
                        .fixedSize()
                        .rotationEffect(.degrees(6))
                        .position(x: 0, y: geo.size.height - 200)
                }
                .foregroundStyle(Color(hex: 0xDCF0D2).opacity(0.05))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                // Flatten to a single screen-sized texture once; no live blur.
                .drawingGroup()
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .clipped()
    }
}

// MARK: - Top bar

struct TopBar: View {
    let model: ChatModel

    var body: some View {
        HStack {
            CircleButton(system: "arrow.left") { model.reset() }
            Spacer()
            HStack(spacing: 10) {
                if model.inChat {
                    CircleButton(system: "square.and.pencil") { model.reset() }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                CircleButton(system: "line.3.horizontal") { }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .animation(.spring(duration: 0.4), value: model.inChat)
    }
}

struct CircleButton: View {
    let system: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Home

struct HomeView: View {
    let model: ChatModel

    @State private var focusIndex = 1

    private let chips = [
        "What can Mal do for me",
        "How was my spending last month",
        "What are the fees",
        "Which countries are supported",
        "How do I open an account"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Salam, Zoe")
                .font(.system(size: 46, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(Theme.lime)
            Text("How can I help you today?")
                .font(.system(size: 21))
                .foregroundStyle(Theme.text2)
                .padding(.top, 14)
            VStack(spacing: 12) {
                ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                    Button {
                        model.ask(chip + "?")
                    } label: {
                        Text(chip)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.text)
                            .padding(.vertical, 17)
                            .padding(.horizontal, 30)
                            .background(Capsule().fill(Theme.surface2))
                    }
                    .buttonStyle(PressStyle())
                    .opacity(opacity(for: index))
                }
            }
            .padding(.top, 70)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeInOut(duration: 0.8)) {
                    focusIndex = (focusIndex + 1) % chips.count
                }
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        switch abs(index - focusIndex) {
        case 0: return 1
        case 1: return 0.55
        case 2: return 0.22
        default: return 0.1
        }
    }
}

// MARK: - Composer

struct Composer: View {
    @Bindable var model: ChatModel
    var focused: FocusState<Bool>.Binding

    private var hasText: Bool {
        !model.input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $model.input, prompt: Text("Ask anything...").foregroundColor(Color(hex: 0x8A9290)))
                .font(.system(size: 18.5))
                .foregroundStyle(Theme.text)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit { model.send() }
                .padding(.leading, 26)
            Image(systemName: "mic")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: 0xCFD5D2))
                .frame(width: 32, height: 32)
            Button {
                if hasText { model.send() }
            } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 46, height: 46)
                    Image(systemName: hasText ? "arrow.up" : "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0C0F10))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(PressStyle())
            .animation(.snappy(duration: 0.25), value: hasText)
        }
        .padding(.trailing, 12)
        .frame(height: 68)
        .background(Capsule().fill(Theme.composer))
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
                .ignoresSafeArea()
        )
    }
}
