import Foundation
import AppKit

/// 使用者設定：放喺 ~/Library/Application Support/BihuaIME/config.json
struct BihuaConfig {
    var strokeKeys: [Character] = ["1", "2", "3", "4", "5"]
    var selectKeys: [Character] = ["q", "w", "e", "r", "t", "z", "x", "c", "v", "b"]
    var prevKey: Character = "y"
    var nextKey: Character = "n"
    var fontSize: CGFloat = 24
    var pageSize: Int = 10
    var showPreedit: Bool = true
    var predict: Bool = true

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("BihuaIME", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("config.json") }

    static let template = """
    {
      "_說明": "筆畫輸入法設定。改完之後執行 reload.sh 就會生效。",
      "_strokeKeys": "五個鍵，依次代表 橫 一、豎 丨、撇 丿、點 丶、折 乛",
      "strokeKeys": ["1", "2", "3", "4", "5"],
      "_selectKeys": "選候選字用。如果同 strokeKeys 撞，以 strokeKeys 優先。",
      "selectKeys": ["q", "w", "e", "r", "t", "y", "u", "i", "o"],
      "_fontSize": "候選窗字體大細",
      "fontSize": 24,
      "_pageSize": "一頁顯示幾多個候選字（最多 9）",
      "pageSize": 9,
      "_showPreedit": "打緊字嘅時候，喺輸入位顯示筆畫符號",
      "showPreedit": true,
      "_predict": "打完一個字之後，提議下一個字（聯想）",
      "predict": true
    }
    """

    static func load() -> BihuaConfig {
        var cfg = BihuaConfig()
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: fileURL.path) {
                try template.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("[Bihua] 寫預設設定失敗: %@", "\(error)")
        }

        guard let data = try? Data(contentsOf: fileURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return cfg
        }

        if let keys = obj["strokeKeys"] as? [String], keys.count == 5 {
            let chars = keys.compactMap { $0.first }
            if chars.count == 5 { cfg.strokeKeys = chars }
        }
        if let keys = obj["selectKeys"] as? [String] {
            let chars = keys.compactMap { $0.first }
            if !chars.isEmpty { cfg.selectKeys = chars }
        }
        if let size = obj["fontSize"] as? Double, size >= 12, size <= 96 {
            cfg.fontSize = CGFloat(size)
        }
        if let page = obj["pageSize"] as? Int, page >= 1, page <= 10 {
            cfg.pageSize = page
        }
        if let pre = obj["showPreedit"] as? Bool {
            cfg.showPreedit = pre
        }
        if let pr = obj["predict"] as? Bool {
            cfg.predict = pr
        }
        if let k = (obj["prevKey"] as? String)?.first { cfg.prevKey = k }
        if let k = (obj["nextKey"] as? String)?.first { cfg.nextKey = k }
        return cfg
    }
}
