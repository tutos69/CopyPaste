import AppKit
import Carbon
import ServiceManagement

enum Accessibility {
    static var trusted: Bool { AXIsProcessTrusted() }

    static func prompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

/// ⌘⇧3 / ⌘⇧4 go to the clipboard instead of a file (same setting as ⌘⇧5 → Options → Clipboard).
enum ScreenshotSettings {
    private static let domain = "com.apple.screencapture" as CFString
    private static let key = "target" as CFString

    static var toClipboard: Bool {
        (CFPreferencesCopyAppValue(key, domain) as? String) == "clipboard"
    }

    static func setToClipboard(_ on: Bool) {
        CFPreferencesSetAppValue(key, (on ? "clipboard" : "file") as CFString, domain)
        CFPreferencesAppSynchronize(domain)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private lazy var panel = HistoryPanelController(store: store)
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var textHotKey: HotKey?
    private var isCapturingText = false
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyPaste")
        menu.delegate = self
        statusItem.menu = menu

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.panel.toggle()
        }
        if hotKey?.registered != true {
            NSLog("CopyPaste: could not register ⌘⇧V (another app may be using it)")
        }
        textHotKey = HotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.captureText()
        }
        if textHotKey?.registered != true {
            NSLog("CopyPaste: could not register ⌘⇧2 (another app may be using it)")
        }

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didInitialSetup") {
            defaults.set(true, forKey: "didInitialSetup")
            ScreenshotSettings.setToClipboard(true)
            if !Accessibility.trusted { Accessibility.prompt() }
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("Mostrar historial  ⌘⇧V", #selector(showHistory)))
        menu.addItem(item("Copiar texto de la pantalla  ⌘⇧2", #selector(captureText)))
        menu.addItem(.separator())

        let screenshots = item("Capturas (⌘⇧3 / ⌘⇧4) al portapapeles", #selector(toggleScreenshots))
        screenshots.state = ScreenshotSettings.toClipboard ? .on : .off
        menu.addItem(screenshots)

        let paste = item(Accessibility.trusted ? "Pegado automático: activo"
                                               : "Activar pegado automático…", #selector(requestAccessibility))
        paste.state = Accessibility.trusted ? .on : .off
        menu.addItem(paste)

        let login = item("Abrir al iniciar sesión", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Borrar historial (excepto anclados)", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Salir", #selector(quit)))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showHistory() { panel.show() }

    /// ⌘⇧2: select an area of the screen and copy the text inside it.
    @objc private func captureText() {
        guard !isCapturingText else { return }

        // Without Screen Recording permission the capture only shows the wallpaper.
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            Toast.show("Da permiso de Grabación de pantalla a CopyPaste y vuelve a intentarlo",
                       symbol: "exclamationmark.triangle.fill")
            return
        }

        isCapturingText = true
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("copypaste-text-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", file.path] // interactive selection, no sound, to a file
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.finishTextCapture(file) }
        }
        do {
            try process.run()
        } catch {
            isCapturingText = false
        }
    }

    private func finishTextCapture(_ file: URL) {
        isCapturingText = false
        guard let data = try? Data(contentsOf: file) else { return } // cancelled with esc
        try? FileManager.default.removeItem(at: file)

        OCR.recognizeText(in: data) { text in
            guard !text.isEmpty else {
                Toast.show("No se encontró texto", symbol: "text.magnifyingglass")
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            Toast.show("Texto copiado")
        }
    }

    @objc private func toggleScreenshots() {
        ScreenshotSettings.setToClipboard(!ScreenshotSettings.toClipboard)
    }

    @objc private func requestAccessibility() {
        Accessibility.prompt()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("CopyPaste: login item error: \(error)")
        }
    }

    @objc private func clearHistory() { store.clearUnpinned() }

    @objc private func quit() { NSApp.terminate(nil) }
}
