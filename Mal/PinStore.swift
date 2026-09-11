import SwiftUI
import Observation

/// One pinned prompt, shared by every variation and kept across launches.
/// Pinning puts the prompt first on the chat's empty state with a pin icon.
@MainActor
@Observable
final class PinStore {
    static let shared = PinStore()

    private static let key = "pinnedPrompt"

    private(set) var pinned: String?

    private init() {
        pinned = UserDefaults.standard.string(forKey: Self.key)
    }

    /// Normalises "How was my spending last month?" and the chip text to one key.
    static func normalize(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("?") || t.hasSuffix(".") { t.removeLast() }
        return t
    }

    func isPinned(_ text: String) -> Bool {
        pinned == Self.normalize(text)
    }

    func pin(_ text: String) {
        pinned = Self.normalize(text)
        UserDefaults.standard.set(pinned, forKey: Self.key)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func unpin() {
        pinned = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Long-press menu shared by suggestion chips and the user's own bubbles.
struct PinMenu: View {
    let prompt: String
    let pins: PinStore

    var body: some View {
        if pins.isPinned(prompt) {
            Button(role: .destructive) { pins.unpin() } label: {
                Label("Unpin prompt", systemImage: "pin.slash")
            }
        } else {
            Button { pins.pin(prompt) } label: {
                Label("Pin this prompt", systemImage: "pin")
            }
        }
        Button { UIPasteboard.general.string = prompt } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}
