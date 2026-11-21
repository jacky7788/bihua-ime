import Foundation

/// 五筆畫編碼表：以簡體筆順編碼，輸出繁體字
final class BihuaEngine {
    static let shared = BihuaEngine()

    private(set) var symbols: [Character] = ["一", "丨", "丿", "丶", "乛"]
    private var codes: [String] = []
    private var table: [[Character]] = []
    private var weights: [[Int]] = []
    private var predictMap: [Character: [Character]] = [:]
    private(set) var loaded = false
    private(set) var totalCodes = 0
    private(set) var totalChars = 0

    private init() {}

    func load() {
        guard !loaded else { return }
        guard let url = Bundle.main.url(forResource: "codes", withExtension: "json") else {
            NSLog("[Bihua] 搵唔到 codes.json")
            return
        }
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["entries"] as? [[Any]] else {
            NSLog("[Bihua] codes.json 格式有問題")
            return
        }

        if let syms = root["symbols"] as? [String] {
            let chars = syms.compactMap { $0.first }
            if chars.count == 5 { symbols = chars }
        }

        let freqRows = (root["freq"] as? [[Any]]) ?? []

        var pairs: [(String, [Character])] = []
        pairs.reserveCapacity(entries.count)
        for e in entries {
            guard e.count == 2,
                  let code = e[0] as? String,
                  let chars = e[1] as? String,
                  !code.isEmpty, !chars.isEmpty else { continue }
            pairs.append((code, Array(chars)))
        }
        // freq 行同 entries 行一一對應，排序前先綁埋一齊
        var bundled: [(String, [Character], [Int])] = []
        bundled.reserveCapacity(pairs.count)
        for (i, p) in pairs.enumerated() {
            var w = [Int](repeating: 0, count: p.1.count)
            if i < freqRows.count {
                let row = freqRows[i]
                for (j, v) in row.enumerated() where j < w.count {
                    if let n = v as? Int { w[j] = n }
                    else if let n = v as? Double { w[j] = Int(n) }
                    else if let s = v as? String, let n = Int(s) { w[j] = n }
                }
            }
            bundled.append((p.0, p.1, w))
        }
        bundled.sort { $0.0 < $1.0 }
        codes = bundled.map { $0.0 }
        table = bundled.map { $0.1 }
        weights = bundled.map { $0.2 }
        loadPredictions()
        totalCodes = codes.count
        totalChars = Set(table.joined()).count
        loaded = true
        NSLog("[Bihua] 載入 %d 個碼 / %d 個字", totalCodes, totalChars)
    }

    private func loadPredictions() {
        guard let url = Bundle.main.url(forResource: "predict", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let map = root["map"] as? [String: [String]] else {
            NSLog("[Bihua] 冇 predict.json，聯想功能停用")
            return
        }
        var out: [Character: [Character]] = [:]
        out.reserveCapacity(map.count)
        for (k, v) in map {
            guard let key = k.first else { continue }
            out[key] = v.compactMap { $0.first }
        }
        predictMap = out
        NSLog("[Bihua] 聯想表 %d 個字", predictMap.count)
    }

    /// 打完一個字之後，跟住最有可能嘅下一個字
    func predictions(for ch: Character) -> [Character] {
        load()
        return predictMap[ch] ?? []
    }

    /// buffer 例如 "2512"；先出完全吻合，再出前綴吻合
    func candidates(for buffer: String, limit: Int = 90) -> [Character] {
        load()
        guard !buffer.isEmpty, !codes.isEmpty else { return [] }

        var lo = 0, hi = codes.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if codes[mid] < buffer { lo = mid + 1 } else { hi = mid }
        }

        var found: [(Character, Int, Bool)] = []
        var i = lo
        while i < codes.count && codes[i].hasPrefix(buffer) {
            let isExact = (codes[i] == buffer)
            for (j, ch) in table[i].enumerated() {
                found.append((ch, j < weights[i].count ? weights[i][j] : 0, isExact))
            }
            i += 1
            if found.count >= limit * 6 { break }
        }
        // 完全吻合優先，再按常見度
        found.sort { a, b in
            if a.2 != b.2 { return a.2 }
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0 < b.0
        }
        var seen = Set<Character>()
        var out: [Character] = []
        for item in found where !seen.contains(item.0) {
            seen.insert(item.0)
            out.append(item.0)
            if out.count >= limit { break }
        }
        return out
    }
}
