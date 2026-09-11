import SwiftUI

/// Picker first; tapping a variation opens its chat. The chat's back arrow returns here.
struct RootView: View {
    @State private var selected: Variant?

    var body: some View {
        ZStack {
            if let variant = selected {
                ChatScreen(variant: variant) {
                    withAnimation(.easeInOut(duration: 0.3)) { selected = nil }
                }
                .id(variant)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VariationMenu { variant in
                    withAnimation(.easeInOut(duration: 0.3)) { selected = variant }
                }
                .background {
                    Backdrop(active: false, thinking: false)
                        .ignoresSafeArea()
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Chat screen for one variation

struct ChatScreen: View {
    let variant: Variant
    let onBack: () -> Void

    @State private var model: ChatModel
    @FocusState private var composerFocused: Bool

    init(variant: Variant, onBack: @escaping () -> Void) {
        self.variant = variant
        self.onBack = onBack
        _model = State(initialValue: ChatModel(variant: variant))
    }

    var body: some View {
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
        // The bar floats over the thread; content scrolls underneath and fades out.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBar(model: model, onBack: onBack)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Composer(model: model, focused: $composerFocused)
        }
        .background {
            Backdrop(active: model.inChat, thinking: model.thinking)
                .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Background

struct Backdrop: View {
    let active: Bool
    let thinking: Bool

    private var glow: Double { thinking ? 0.4 : (active ? 0.26 : 0.16) }

    var body: some View {
        ZStack {
            Theme.bg
            // Soft ellipse fading out well above the first card; never a band.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: 0x125C48).opacity(glow), location: 0),
                    .init(color: Color(hex: 0x125C48).opacity(glow * 0.35), location: 0.45),
                    .init(color: .clear, location: 1)
                ]),
                center: UnitPoint(x: 0.5, y: -0.2),
                startRadius: 0,
                endRadius: 520
            )
            .scaleEffect(x: 1.5, y: 1, anchor: .top)
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
    }
}

// MARK: - Top bar

struct TopBar: View {
    let model: ChatModel
    let onBack: () -> Void

    var body: some View {
        HStack {
            CircleButton(system: "arrow.left", action: onBack)
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
        .padding(.bottom, 8)
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
                .glassCircle()
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Home (greeting + suggested prompts)

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
                            .glassCapsule()
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
        case 1: return 0.6
        case 2: return 0.3
        default: return 0.18
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
            TextField("", text: $model.input, prompt: Text("Ask anything...").foregroundColor(Color(hex: 0x9AA29F)))
                .font(.system(size: 18.5))
                .foregroundStyle(Theme.text)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit { model.send() }
                .padding(.leading, 24)
            Image(systemName: "mic")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: 0xCFD5D2))
                .frame(width: 32, height: 32)
            Button {
                if hasText { model.send() }
            } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 44, height: 44)
                    Image(systemName: hasText ? "arrow.up" : "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0C0F10))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(PressStyle())
            .animation(.snappy(duration: 0.25), value: hasText)
        }
        .padding(.trailing, 10)
        .frame(height: 64)
        .glassCapsule(interactive: false)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
