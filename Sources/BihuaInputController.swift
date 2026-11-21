import Cocoa
import InputMethodKit

func bdebug(_ msg: String) {
    guard FileManager.default.fileExists(atPath: "/tmp/bihua-debug") else { return }
    let line = "\(Date().timeIntervalSince1970) \(msg)\n"
    let path = "/tmp/bihua.log"
    if let fh = FileHandle(forWritingAtPath: path) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        fh.closeFile()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

private enum Key {
    static let space: UInt16 = 49
    static let ret: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let delete: UInt16 = 51
    static let escape: UInt16 = 53
    static let tab: UInt16 = 48
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126

    // 數字小鍵盤 1..9
    static let numpad: [UInt16: Int] = [
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5,
        88: 6, 89: 7, 91: 8, 92: 9,
    ]

    // 主鍵盤上排 1..5（同小鍵盤分開）
    static let topRowDigits: Set<UInt16> = [18, 19, 20, 21, 23]
}

@objc(BihuaInputController)
final class BihuaInputController: IMKInputController {

    private var buffer: [Int] = []
    private var candidates: [Character] = []
    private var selected = 0
    private var pageOffset = 0

    // 聯想（打完一個字之後建議下一個字）
    private var suggestions: [Character] = []
    private var suggesting = false
    private var suggestToken = 0

    private lazy var panel = CandidatePanel()
    private let headless = ProcessInfo.processInfo.environment["BIHUA_HEADLESS"] == "1"
    private let config = BihuaConfig.load()

    // MARK: - 生命週期

    override func activateServer(_ sender: Any!) {
        if let c = sender as? IMKTextInput {
            bdebug("activateServer client=\(c.bundleIdentifier() ?? "nil")")
        }
        super.activateServer(sender)
        reset()
        BihuaEngine.shared.load()
    }

    override func deactivateServer(_ sender: Any!) {
        bdebug("deactivateServer")
        if !buffer.isEmpty, let client = sender as? IMKTextInput {
            commit(index: pageOffset + selected, client: client)
        }
        reset()
        dismissSuggestion()
        if !headless { panel.hidePanel() }
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if !buffer.isEmpty, let client = sender as? IMKTextInput {
            commit(index: pageOffset + selected, client: client)
        }
        reset()
        dismissSuggestion()
        if !headless { panel.hidePanel() }
    }

    // MARK: - 按鍵

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        // Caps Lock 開 = 英文模式，完全唔攔
        if event.modifierFlags.contains(.capsLock) {
            if !buffer.isEmpty { cancel(client: client) }
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            return false
        }

        let typed = (event.charactersIgnoringModifiers ?? "").first
        let code = event.keyCode

        // 聯想模式：打完一個字，等緊你揀下一個
        if buffer.isEmpty && suggesting {
            if code == Key.escape {
                dismissSuggestion()
                return true
            }
            if let typed = typed,
               !config.strokeKeys.contains(typed),
               let slot = config.selectKeys.firstIndex(of: typed),
               slot < suggestions.count {
                let ch = suggestions[slot]
                client.insertText(String(ch),
                                  replacementRange: NSRange(location: NSNotFound, length: 0))
                dismissSuggestion()
                startSuggestion(after: ch, client: client)
                return true
            }
            // 其他鍵：先收埋聯想，再當正常輸入
            dismissSuggestion()
        }

        if !buffer.isEmpty {
            // 1. 翻頁：Y = 上一頁、N = 下一頁（等於原版 ◀ ▶）
            if let typed = typed, typed == config.nextKey {
                turnPage(by: 1, client: client)
                return true
            }
            if let typed = typed, typed == config.prevKey {
                turnPage(by: -1, client: client)
                return true
            }
            // 2. 小鍵盤數字 = 直接揀第 N 個
            if let n = Key.numpad[code], pageOffset + n - 1 < candidates.count {
                return commit(index: pageOffset + n - 1, client: client)
            }
            // 3. Esc 取消
            if code == Key.escape {
                cancel(client: client)
                return true
            }
            // 4. 退格 = 刪一個筆畫
            if code == Key.delete || code == 0x33 {
                buffer.removeLast()
                if buffer.isEmpty {
                    cancel(client: client)
                } else {
                    refresh(client: client)
                }
                return true
            }
            // 5. 空白 / Enter = 確認
            if code == Key.space || code == Key.ret || code == Key.keypadEnter {
                return commit(index: pageOffset + selected, client: client)
            }
            // 6. 方向鍵 / Tab 喺本頁內移動
            if code == Key.down || code == Key.right || code == Key.tab {
                move(by: 1, client: client)
                return true
            }
            if code == Key.up || code == Key.left {
                move(by: -1, client: client)
                return true
            }
            // 7. 自訂選字鍵（q w e r t z x c v b ...）
            if let typed = typed,
               !config.strokeKeys.contains(typed),
               let slot = config.selectKeys.firstIndex(of: typed) {
                let target = pageOffset + slot
                if target < candidates.count {
                    return commit(index: target, client: client)
                }
                return true      // 超出範圍：食咗個字，唔好漏落文件
            }
        }

        // 8. 筆畫鍵
        if let typed = typed, let idx = config.strokeKeys.firstIndex(of: typed) {
            if typed.isNumber && !Key.topRowDigits.contains(code) {
                return false     // 數字鍵只認主鍵盤上排，小鍵盤留返揀字
            }
            buffer.append(idx + 1)
            refresh(client: client)
            return true
        }

        return false
    }

    // MARK: - 內部

    private func reset() {
        buffer.removeAll()
        candidates.removeAll()
        selected = 0
        pageOffset = 0
    }

    private func codeString() -> String {
        buffer.map { String($0) }.joined()
    }

    private func visibleCandidates() -> [Character] {
        guard !candidates.isEmpty else { return [] }
        let start = min(pageOffset, candidates.count - 1)
        let end = min(start + config.pageSize, candidates.count)
        return Array(candidates[start..<end])
    }

    private func refresh(client: IMKTextInput) {
        candidates = BihuaEngine.shared.candidates(for: codeString())
        selected = 0
        pageOffset = 0
        updatePreedit(client: client)
        if headless { return }
        if candidates.isEmpty {
            panel.hidePanel()
        } else {
            redrawPanel(client: client)
        }
    }

    private func move(by delta: Int, client: IMKTextInput) {
        let count = visibleCandidates().count
        guard count > 0 else { return }
        selected = max(0, min(count - 1, selected + delta))
        redrawPanel(client: client)
    }

    // MARK: - 聯想

    private func startSuggestion(after ch: Character, client: IMKTextInput) {
        let next = BihuaEngine.shared.predictions(for: ch)
        guard !next.isEmpty else {
            dismissSuggestion()
            if !headless { panel.hidePanel() }
            return
        }
        suggestions = Array(next.prefix(config.pageSize))
        suggesting = true
        if headless { return }
        redrawSuggestion(client: client)
        scheduleSuggestionTimeout()
    }

    private func redrawSuggestion(client: IMKTextInput) {
        guard !suggestions.isEmpty else { panel.hidePanel(); return }
        let labels = suggestions.indices.map { i -> String in
            i < config.selectKeys.count ? String(config.selectKeys[i]) : "\(i + 1)"
        }
        panel.show(chars: suggestions,
                   labels: labels,
                   selected: -1,
                   at: caretRect(client),
                   fontSize: config.fontSize,
                   hasPrev: false,
                   hasNext: false,
                   pageText: "聯",
                   prevKey: "",
                   nextKey: "")
    }

    private func scheduleSuggestionTimeout() {
        suggestToken += 1
        let token = suggestToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self, self.suggestToken == token, self.suggesting else { return }
            self.dismissSuggestion()
        }
    }

    private func dismissSuggestion() {
        suggesting = false
        suggestions.removeAll()
        if !headless { panel.hidePanel() }
    }

    private func turnPage(by delta: Int, client: IMKTextInput) {
        guard !candidates.isEmpty else { return }
        let perPage = config.pageSize
        let maxPage = max(0, (candidates.count - 1) / perPage)
        let current = pageOffset / perPage
        let next = max(0, min(maxPage, current + delta))
        guard next != current else { return }
        pageOffset = next * perPage
        selected = 0
        redrawPanel(client: client)
    }

    private func updatePreedit(client: IMKTextInput) {
        guard config.showPreedit else {
            clearMarked(client)
            return
        }
        let symbols = BihuaEngine.shared.symbols
        let text = buffer.map { String(symbols[$0 - 1]) }.joined()
        let attr = NSAttributedString(string: text, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: NSColor.tertiaryLabelColor,
        ])
        client.setMarkedText(attr,
                             selectionRange: NSRange(location: (text as NSString).length, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func clearMarked(_ client: IMKTextInput) {
        client.setMarkedText("",
                             selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func redrawPanel(client: IMKTextInput) {
        if headless { return }
        let visible = visibleCandidates()
        guard !visible.isEmpty else { panel.hidePanel(); return }

        let labels = visible.indices.map { i -> String in
            i < config.selectKeys.count ? String(config.selectKeys[i]) : "\(i + 1)"
        }
        let perPage = max(1, config.pageSize)
        let totalPages = max(1, (candidates.count + perPage - 1) / perPage)
        let currentPage = pageOffset / perPage + 1

        panel.show(chars: visible,
                   labels: labels,
                   selected: min(selected, visible.count - 1),
                   at: caretRect(client),
                   fontSize: config.fontSize,
                   hasPrev: pageOffset > 0,
                   hasNext: pageOffset + visible.count < candidates.count,
                   pageText: totalPages > 1 ? "\(currentPage)/\(totalPages)" : "",
                   prevKey: String(config.prevKey),
                   nextKey: String(config.nextKey))
    }

    private func caretRect(_ client: IMKTextInput) -> NSRect {
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        if rect.width <= 0 || rect.height <= 0 {
            let mouse = NSEvent.mouseLocation
            rect = NSRect(x: mouse.x, y: mouse.y - 20, width: 2, height: 20)
        }
        return rect
    }

    @discardableResult
    private func commit(index: Int, client: IMKTextInput) -> Bool {
        guard !buffer.isEmpty else { return false }
        guard index >= 0, index < candidates.count else {
            cancel(client: client)
            return true
        }
        let ch = String(candidates[index])
        client.insertText(ch, replacementRange: NSRange(location: NSNotFound, length: 0))
        reset()
        if let c = ch.first, config.predict {
            startSuggestion(after: c, client: client)
        } else if !headless {
            panel.hidePanel()
        }
        return true
    }

    private func cancel(client: IMKTextInput) {
        reset()
        if !headless { panel.hidePanel() }
        clearMarked(client)
    }
}
