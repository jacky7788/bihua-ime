import Cocoa
import InputMethodKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let name = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
            ?? "Bihua_1_Connection"
        server = IMKServer(name: name, bundleIdentifier: Bundle.main.bundleIdentifier)
        if server == nil {
            NSLog("[Bihua] ⚠️ IMKServer 起唔到")
        } else {
            NSLog("[Bihua] 輸入法已啟動")
        }
        BihuaEngine.shared.load()
        let cls = NSClassFromString("BihuaInputController")
        bdebug("startup: class=\(cls.map { NSStringFromClass($0) } ?? "❌ nil")")
    }
}

// 自我測試：唔使開介面，直接驗編碼表
if CommandLine.arguments.contains("--selftest") {
    BihuaEngine.shared.load()
    let engine = BihuaEngine.shared
    print("碼數 \(engine.totalCodes)，可輸出字 \(engine.totalChars)")

    var fails = 0
    let probes: [(String, [Character])] = [
        ("2512", ["中"]),
        ("34", ["人", "入"]),
        ("134", ["大"]),
        ("551", ["馬"]),
        ("3121534", ["我"]),
        ("11234", ["未", "末"]),
    ]
    for (code, must) in probes {
        let got = engine.candidates(for: code)
        let head = String(got.prefix(8))
        let ok = must.allSatisfy { got.contains($0) }
        if !ok { fails += 1 }
        print("  \(ok ? "✓" : "✗") \(code) -> \(head)\(got.count > 8 ? " …(\(got.count))" : "")")
    }
    // 前綴查詢
    let prefix = engine.candidates(for: "251")
    print("  前綴 251 -> \(String(prefix.prefix(12))) …(\(prefix.count))")
    if prefix.isEmpty { fails += 1 }

    print(fails == 0 ? "SELFTEST OK" : "SELFTEST FAILED (\(fails))")
    exit(fails == 0 ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
