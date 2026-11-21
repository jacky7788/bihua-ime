import Cocoa

func out(_ s: String) {
    let line = s + "\n"
    if let fh = FileHandle(forWritingAtPath: "/tmp/testime.log") {
        fh.seekToEndOfFile(); fh.write(line.data(using: .utf8)!); fh.closeFile()
    } else { try? line.write(toFile: "/tmp/testime.log", atomically: true, encoding: .utf8) }
}

// 端到端測試：開一個真窗口，用真 NSEvent 打字，睇輸入法有冇真係寫入文字
final class TestDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var textView: NSTextView!
    var steps: [(Double, () -> Void)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 240, y: 320, width: 520, height: 180),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "筆畫輸入法 — 端到端測試"
        window.level = .floating

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 180))
        textView = NSTextView(frame: NSRect(x: 24, y: 28, width: 472, height: 110))
        textView.font = NSFont.systemFont(ofSize: 30)
        textView.isRichText = false
        container.addSubview(textView)
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        NSApp.activate(ignoringOtherApps: true)

        schedule()
    }

    private func post(_ chars: String, _ keyCode: UInt16) {
        guard let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                       timestamp: ProcessInfo.processInfo.systemUptime,
                                       windowNumber: window.windowNumber, context: nil,
                                       characters: chars, charactersIgnoringModifiers: chars,
                                       isARepeat: false, keyCode: keyCode) else { return }
        NSApp.postEvent(e, atStart: false)
    }

    private func schedule() {
        let keys: [(String, UInt16)] = [("2", 19), ("5", 23), ("1", 18), ("2", 19)]
        var t = 1.2
        for (ch, code) in keys {
            steps.append((t, { [weak self] in self?.post(ch, code) }))
            t += 0.15
        }
        steps.append((t + 0.9, { [weak self] in
            guard let self = self else { return }
            let ctx = self.textView.inputContext
            out("STEP1 marked=[\(self.textView.string)] ctxNil=\(ctx == nil) appActive=\(NSApp.isActive) keyWindow=\(self.window.isKeyWindow) firstResp=\(String(describing: self.window.firstResponder))")
        }))
        steps.append((t + 1.0, { [weak self] in self?.post(" ", 49) }))
        steps.append((t + 1.9, { [weak self] in
            guard let self = self else { return }
            out("STEP2 text=[\(self.textView.string)]")
        }))
        // 再打一次，然後用 Enter 確認
        let more: [(String, UInt16)] = [("5", 23), ("5", 23), ("1", 18)]
        var t2 = t + 2.2
        for (ch, code) in more {
            steps.append((t2, { [weak self] in self?.post(ch, code) }))
            t2 += 0.15
        }
        steps.append((t2 + 0.3, { [weak self] in
            guard let self = self else { return }
            out("STEP3 marked=[\(self.textView.string)]")
        }))
        steps.append((t2 + 0.9, { [weak self] in self?.post("\r", 36) }))
        steps.append((t2 + 1.8, { [weak self] in
            guard let self = self else { return }
            out("FINAL=[\(self.textView.string)]")
            NSApp.terminate(nil)
        }))

        for (delay, action) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        }
    }
}

let app = NSApplication.shared
let delegate = TestDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
