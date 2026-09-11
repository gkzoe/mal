import SwiftUI

/// Picker first; tapping a variation pushes its chat. The chat's back arrow pops back here.
struct RootView: View {
    @State private var path: [Variant] = []

    var body: some View {
        NavigationStack(path: $path) {
            VariationMenu { variant in path = [variant] }
                .background {
                    Backdrop(active: false, thinking: false)
                        .ignoresSafeArea()
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Variant.self) { variant in
                    ChatScreen(variant: variant) { path.removeAll() }
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                }
        }
        .tint(Theme.lime)
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
        GeometryReader { outer in
            let statusTop = outer.safeAreaInsets.top
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
            // Barriers sit above the thread and below the bar and composer.
            // Measured from the screen edges so there is never a gap.
            .overlay {
                VStack(spacing: 0) {
                    TopBarrier(visible: model.inChat, thinking: model.thinking)
                        .frame(height: statusTop + 64 + 12)
                    Spacer(minLength: 0)
                    BottomBarrier(visible: model.inChat)
                        .frame(height: outer.safeAreaInsets.bottom + 78 + 40)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
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
}

/// Green progressive blur between the top bar and the chat. The glow drifts
/// slowly so it reads as light rather than a flat overlay.
struct TopBarrier: View {
    let visible: Bool
    let thinking: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.35),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // Base tint so the very top is always a little green.
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x1E7A5A).opacity(0.3), location: 0),
                        .init(color: Color(hex: 0x1E7A5A).opacity(0), location: 0.65)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Drifting pool of light.
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: 0x23885F).opacity(0.55), location: 0),
                        .init(color: Color(hex: 0x1B6B50).opacity(0.22), location: 0.5),
                        .init(color: .clear, location: 1)
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.05),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.6
                )
                .frame(width: geo.size.width * 1.6, height: geo.size.height * 1.5)
                .offset(
                    x: drift ? geo.size.width * 0.18 : -geo.size.width * 0.18,
                    y: drift ? -geo.size.height * 0.1 : geo.size.height * 0.05
                )
                .scaleEffect(drift ? 1.08 : 0.94)
                .opacity(thinking ? 1 : 0.75)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: drift)
                .animation(.easeInOut(duration: 0.8), value: thinking)
            }
            .clipped()
            // Whatever the layers do, the band is fully transparent at its bottom edge.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.3),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: visible)
        .onAppear { drift = true }
    }
}

/// Progressive blur under the composer, tinted to the page background.
struct BottomBarrier: View {
    let visible: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.55),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            LinearGradient(
                stops: [
                    .init(color: Theme.bg.opacity(0), location: 0),
                    .init(color: Theme.bg.opacity(0.7), location: 0.5),
                    .init(color: Theme.bg.opacity(0.96), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        // Same guarantee at the top edge of the bottom band.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: visible)
    }
}

// MARK: - Background

struct Backdrop: View {
    let active: Bool
    let thinking: Bool

    private var glow: Double { thinking ? 0.55 : (active ? 0.4 : 0.35) }

    var body: some View {
        ZStack {
            Theme.bg
            // Soft ellipse fading out well above the first card; never a band.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: 0x1E7A5A).opacity(glow), location: 0),
                    .init(color: Color(hex: 0x156048).opacity(glow * 0.55), location: 0.4),
                    .init(color: .clear, location: 1)
                ]),
                center: UnitPoint(x: 0.5, y: -0.25),
                startRadius: 0,
                endRadius: 560
            )
            .scaleEffect(x: 1.5, y: 1, anchor: .top)
            .animation(.easeInOut(duration: 1.2), value: glow)
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
                .contentShape(Circle())
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
