import Cocoa
import InputMethodKit

/// 假 client：記錄輸入法實際叫佢做咩
final class MockClient: NSObject, IMKTextInput {
    var committed: [String] = []
    var marked: String = ""

    func insertText(_ string: Any!, replacementRange: NSRange) {
        if let s = string as? String {
            committed.append(s)
        } else if let a = string as? NSAttributedString {
            committed.append(a.string)
        }
        marked = ""
    }

    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        if let s = string as? String {
            marked = s
        } else if let a = string as? NSAttributedString {
            marked = a.string
        }
    }

    func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }
    func markedRange() -> NSRange { NSRange(location: 0, length: marked.utf16.count) }
    func length() -> Int { 0 }
    func substring(fromRange range: NSRange) -> String! { "" }
    func string(from range: NSRange, actualRange: NSRangePointer?) -> String? { "" }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! {
        NSAttributedString(string: "")
    }
    func firstRect(forCharacterRange range: NSRange,
                   actualRange: NSRangePointer?) -> NSRect {
        NSRect(x: 120, y: 120, width: 2, height: 20)
    }
    func characterIndex(for point: NSPoint,
                        tracking mappingMode: IMKLocationToOffsetMappingMode,
                        inMarkedRange markedRange: UnsafeMutablePointer<ObjCBool>?) -> Int {
        0
    }
    func attributes(forCharacterIndex index: Int,
                    lineHeightRectangle rect: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! {
        if let rect = rect { rect.pointee = NSRect(x: 100, y: 100, width: 2, height: 20) }
        return [:]
    }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String?) {}
    func selectMode(_ modeIdentifier: String?) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String? { "test.client" }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String? { "mock-client" }
}

/// 字元 -> keyCode（US 鍵盤）
let charKeyCodes: [Character: UInt16] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
    "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
    "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
    "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
    "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
]

private func key(_ ch: String, _ code: UInt16, flags: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                     windowNumber: 0, context: nil,
                     characters: ch, charactersIgnoringModifiers: ch,
                     isARepeat: false, keyCode: code)!
}

let SPACE: UInt16 = 49, DEL: UInt16 = 51, ESC: UInt16 = 53, NUMPAD1: UInt16 = 83

var failures = 0

func check(_ name: String, _ cond: Bool, _ detail: String = "") {
    print("\(cond ? "✓" : "✗") \(name)\(detail.isEmpty ? "" : "  (\(detail))")")
    if !cond { failures += 1 }
}

_ = NSApplication.shared
let cfg = BihuaConfig.load()
print("設定：strokeKeys=\(String(cfg.strokeKeys))  selectKeys=\(String(cfg.selectKeys))")

let controller = BihuaInputController()
let client = MockClient()

/// 打一個筆畫（1=橫 2=豎 3=撇 4=點 5=折），跟設定檔嘅鍵位
@discardableResult
func stroke(_ n: Int) -> Bool {
    let ch = cfg.strokeKeys[n - 1]
    return controller.handle(key(String(ch), charKeyCodes[ch] ?? 0), client: client)
}

@discardableResult
func press(_ ch: String) -> Bool {
    let c = ch.first!
    return controller.handle(key(ch, charKeyCodes[c] ?? 0), client: client)
}

// 1. 中 = 丨フ一丨 = 2512
for n in [2, 5, 1, 2] { stroke(n) }
check("2512 預輸入", client.marked == "丨乛一丨", "marked=\(client.marked)")
check("空白確認", controller.handle(key(" ", SPACE), client: client))
check("2512 = 中", client.committed.last == "中", "got=\(client.committed.last ?? "nil")")

// 2. 馬 = 551（簡體「马」筆順）
for n in [5, 5, 1] { stroke(n) }
controller.handle(key(" ", SPACE), client: client)
check("551 = 馬（簡入繁出）", client.committed.last == "馬", "got=\(client.committed.last ?? "nil")")

// 3. 退格刪一個筆畫
stroke(2); stroke(5)
controller.handle(key("\u{7f}", DEL), client: client)
check("退格後剩一個筆畫", client.marked == "丨", "marked=\(client.marked)")
controller.handle(key("\u{1b}", ESC), client: client)
check("Esc 清空", client.marked == "", "marked=\(client.marked)")

// 4. 數字鍵揀字（而家筆畫係字母，數字應該空返出嚟）
for n in [5, 5, 1] { stroke(n) }
check("q 揀第一個候選", press("q") && client.committed.last == "馬",
      "got=\(client.committed.last ?? "nil")")

// 4a. N = 下一頁、Y = 上一頁（原版 ◀ ▶）
controller.handle(key("\u{1b}", ESC), client: client)
let pool = BihuaEngine.shared.candidates(for: "34")
for n in [3, 4] { stroke(n) }
controller.handle(key("n", 45), client: client)
controller.handle(key("q", 12), client: client)
check("N 翻到第 2 頁，q 揀第 11 個",
      pool.count > 10 && client.committed.last == String(pool[10]),
      "got=\(client.committed.last ?? "nil") expect=\(pool.count > 10 ? String(pool[10]) : "?")")

controller.handle(key("\u{1b}", ESC), client: client)
for n in [3, 4] { stroke(n) }
controller.handle(key("n", 45), client: client)
controller.handle(key("y", 16), client: client)
controller.handle(key("q", 12), client: client)
check("N 之後 Y 返第 1 頁", client.committed.last == "人",
      "got=\(client.committed.last ?? "nil")")

// 4a2. B = 第 10 個候選
controller.handle(key("\u{1b}", ESC), client: client)
for n in [3, 4] { stroke(n) }
let expect10 = BihuaEngine.shared.candidates(for: "34")
controller.handle(key("b", charKeyCodes["b"] ?? 11), client: client)
check("B = 第 10 個候選", expect10.count > 9 && client.committed.last == String(expect10[9]),
      "got=\(client.committed.last ?? "nil") expect=\(expect10.count > 9 ? String(expect10[9]) : "?")")

// 4b. 數字鍵而家完全放行（可以正常打數字）
for n in [5, 5, 1] { stroke(n) }
check("數字 1 唔再被攔（會漏落文件）", press("1") == false)

// 5. 小鍵盤一樣揀到
controller.handle(key("\u{1b}", ESC), client: client)
for n in [5, 5, 1] { stroke(n) }
controller.handle(key("1", NUMPAD1), client: client)
check("小鍵盤 1 揀字", client.committed.last == "馬", "got=\(client.committed.last ?? "nil")")

// 6. 唔係筆畫鍵嘅字母要交返系統
check("字母 m 交返系統（z 而家係揀字鍵）", press("m") == false)
check("字母 i 唔係筆畫（空 buffer 時放行）", press("i") == false)

// 7. Command 組合鍵唔搶
stroke(2)
check("⌘S 交返系統",
      controller.handle(key("s", charKeyCodes["s"]!, flags: .command), client: client) == false)

// 8. Shift 大寫唔當筆畫（可以打英文細楷以外嘅字）
controller.handle(key("\u{1b}", ESC), client: client)
check("Shift+A 交返系統",
      controller.handle(key("A", charKeyCodes["a"]!, flags: .shift), client: client) == false)

// 8b. Caps Lock 開 = 英文模式
controller.handle(key("\u{1b}", ESC), client: client)
check("Caps Lock 開時連 a 都放行",
      controller.handle(key("a", charKeyCodes["a"]!, flags: .capsLock), client: client) == false)

// 9. 連打多個字
controller.handle(key("\u{1b}", ESC), client: client)
client.committed.removeAll()
for n in [3, 4] { stroke(n) }        // 34 = 人
controller.handle(key(" ", SPACE), client: client)
check("34 = 人", client.committed.last == "人", "got=\(client.committed.last ?? "nil")")

// 9b. 常見度排序
let c134 = BihuaEngine.shared.candidates(for: "134")
check("常見度：134 第一個係「大」", c134.first == "大",
      "got=\(c134.first.map(String.init) ?? "nil")")
let c251 = BihuaEngine.shared.candidates(for: "251")
check("常見度：251 頭五個有「是」", c251.prefix(5).contains("是"),
      "got=\(String(c251.prefix(6)))")
let c34 = BihuaEngine.shared.candidates(for: "34")
check("常見度：34 之後排住常用字", c34.prefix(8).contains("個"),
      "got=\(String(c34.prefix(8)))")

// 9c. 聯想：打完一個字建議下一個
controller.handle(key("\u{1b}", ESC), client: client)
for n in [2, 5, 1, 2] { stroke(n) }              // 2512
controller.handle(key(" ", SPACE), client: client)   // 中
let okSuggest = press("q") && client.committed.last == "國"
check("聯想：打完「中」撳 q 出「國」", okSuggest,
      "got=\(client.committed.last ?? "nil")")

// 9d. 聯想唔會阻住打筆畫
controller.handle(key("\u{1b}", ESC), client: client)
for n in [2, 5, 1, 2] { stroke(n) }
controller.handle(key(" ", SPACE), client: client)   // 中（可能已經有聯想）
stroke(2)                                            // 直接打筆畫
check("聯想時打筆畫 → 開始新輸入", client.marked == "丨", "marked=\(client.marked)")

// 9e. Esc 收埋聯想
controller.handle(key("\u{1b}", ESC), client: client)
check("Esc 之後冇殘留", client.marked == "" && press("q") == false)

// 9f. 異體字（OpenCC 反向表補齊）
let v1 = BihuaEngine.shared.candidates(for: "4354")        // 为 -> 爲 為
let v2 = BihuaEngine.shared.candidates(for: "2511211")     // 里 -> 裏 裡
let v3 = BihuaEngine.shared.candidates(for: "132522111")   // 面 -> 麪 麵
check("異體：為 打得出", v1.contains("為"), "got=\(String(v1.prefix(4)))")
check("異體：裡 打得出", v2.contains("裡"), "got=\(String(v2.prefix(5)))")
check("異體：麵 打得出", v3.contains("麵"), "got=\(String(v3.prefix(4)))")

// 10. 候選窗尺寸（10 個字 + 前後頁）
let canvas = CandidateCanvas()
canvas.setup(chars: Array("一二三四五六七八九十"),
             labels: cfg.selectKeys.map { String($0) },
             selected: 3, fontSize: 24,
             hasPrev: true, hasNext: true, pageText: "2/9")
let sz = canvas.fittingSize
check("候選窗尺寸合理", sz.width > 380 && sz.width < 700 && sz.height > 40,
      "\(Int(sz.width))x\(Int(sz.height))")

print(failures == 0 ? "\nCONTROLLER TEST OK" : "\nCONTROLLER TEST FAILED (\(failures))")
exit(failures == 0 ? 0 : 1)
