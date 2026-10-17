import AppKit

/// Small message that appears near the bottom of the screen and fades out by itself.
enum Toast {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(_ message: String, symbol: String = "checkmark.circle.fill") {
        hideWork?.cancel()
        panel?.orderOut(nil)

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 16, weight: .medium)
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let stack = NSStackView(views: [icon, label])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 18)
        let size = stack.fittingSize

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = size.height / 2
        background.layer?.masksToBounds = true
        stack.frame = background.bounds
        background.addSubview(stack)

        let toast = NSPanel(contentRect: background.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = true
        toast.level = .statusBar
        toast.ignoresMouseEvents = true
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toast.contentView = background

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            toast.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 80))
        }
        toast.orderFrontRegardless()
        panel = toast

        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                toast.animator().alphaValue = 0
            }, completionHandler: {
                toast.orderOut(nil)
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }
}
