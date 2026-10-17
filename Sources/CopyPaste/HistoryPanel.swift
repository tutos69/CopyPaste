import AppKit
import SwiftUI

final class PanelState: ObservableObject {
    @Published var selected = 0
}

/// Borderless, non-activating panel: the app you were typing in stays frontmost,
/// so the simulated ⌘V lands there.
final class HistoryPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let keyHandler, keyHandler(event) { return }
        super.sendEvent(event)
    }
}

final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardStore
    private let state = PanelState()
    private let panel: HistoryPanel
    private let size = NSSize(width: 360, height: 460)

    init(store: ClipboardStore) {
        self.store = store
        panel = HistoryPanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.nonactivatingPanel, .borderless],
                             backing: .buffered, defer: false)
        super.init()

        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        let root = HistoryView(store: store, state: state,
                               onSelect: { [weak self] item in self?.select(item) },
                               onClose: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        panel.contentView = background
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        state.selected = 0
        panel.setFrameOrigin(originNearMouse())
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.invalidateShadow()
    }

    func close() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func originNearMouse() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        let x = min(max(mouse.x - size.width / 2, frame.minX + 8), frame.maxX - size.width - 8)
        let y = min(max(mouse.y - size.height - 12, frame.minY + 8), frame.maxY - size.height - 8)
        return NSPoint(x: x, y: y)
    }

    private func select(_ item: ClipItem) {
        store.copyToPasteboard(item)
        close()
        guard Accessibility.trusted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Self.simulatePaste() }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let items = store.items
        switch Int(event.keyCode) {
        case 53: // esc
            close()
        case 125: // down
            if !items.isEmpty { state.selected = min(state.selected + 1, items.count - 1) }
        case 126: // up
            state.selected = max(state.selected - 1, 0)
        case 36, 76: // return, enter
            if items.indices.contains(state.selected) { select(items[state.selected]) }
        case 51, 117: // delete, forward delete
            if items.indices.contains(state.selected) {
                store.remove(items[state.selected])
                state.selected = min(state.selected, max(store.items.count - 1, 0))
            }
        default:
            if let chars = event.charactersIgnoringModifiers, let n = Int(chars),
               (1...9).contains(n), items.indices.contains(n - 1) {
                select(items[n - 1])
                return true
            }
            return false
        }
        return true
    }
}

// MARK: - Views

struct HistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var state: PanelState
    var onSelect: (ClipItem) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Portapapeles").font(.headline)
                Spacer()
                Button("Borrar todo") { store.clearUnpinned() }
                    .buttonStyle(.link)
                    .disabled(store.items.allSatisfy(\.pinned))
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 32))
                    Text("Aún no hay nada aquí").font(.headline)
                    Text("Copia texto o haz una captura con ⌘⇧4 y aparecerá en esta lista.")
                        .multilineTextAlignment(.center)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, index: index, store: store,
                                        selected: index == state.selected,
                                        onHover: { state.selected = index })
                                    .id(item.id)
                                    .onTapGesture { onSelect(item) }
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: state.selected) { _, newValue in
                        guard store.items.indices.contains(newValue) else { return }
                        proxy.scrollTo(store.items[newValue].id)
                    }
                }
            }

            Divider()
            Text("↑↓ navegar · ↩ pegar · 1–9 rápido · ⌫ borrar · esc cerrar")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(6)
        }
        .frame(width: 360, height: 460)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let store: ClipboardStore
    let selected: Bool
    var onHover: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            content.frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                if index < 9 {
                    Text("\(index + 1)").font(.caption2.monospacedDigit())
                }
                if hovering || item.pinned {
                    Button { store.togglePin(item) } label: {
                        Image(systemName: item.pinned ? "pin.fill" : "pin")
                    }
                    .buttonStyle(.plain)
                    .help(item.pinned ? "Desanclar" : "Anclar (no se borra con «Borrar todo»)")
                }
                if hovering {
                    Button { store.remove(item) } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain)
                        .help("Eliminar")
                }
            }
            .frame(width: 18)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside { onHover() }
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            Text(String((item.text ?? "").prefix(400)))
                .font(.system(size: 12))
                .lineLimit(4)
                .truncationMode(.tail)
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Imagen no disponible").foregroundStyle(.secondary)
            }
        }
    }
}
