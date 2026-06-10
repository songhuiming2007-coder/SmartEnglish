import Foundation

class WordDictionary {
    static let shared = WordDictionary()

    private var entries: [(word: String, freq: Int)] = []
    /// 内存缓存（启动时从 SQLite 加载一次）
    private var userFreqCache: [String: Int] = [:]
    private var properNouns: [String: String] = [:]  // lowercase -> standard form
    private var contractions: [String: String] = [:]  // lowercase -> standard form with apostrophe
    /// 有歧义的缩写词（本身也是常用词），不强制放首位
    private let ambiguousContractions: Set<String> = ["id", "well", "were", "cant", "wont"]
    /// bigram: [prev_word: [next_word: freq]]
    private var bigrams: [String: [String: Int]] = [:]
    /// 上一个上屏的词，用于 bigram 查询
    private var lastWord: String = ""
    /// 用户 bigram 缓存（避免每次 query 都查 SQLite）
    private var lastWordBigramCache: (word: String, bigrams: [String: Int])? = nil

    private init() {
        loadBuiltIn()
        userFreqCache = UserDatabase.shared.loadAllUserWordFreq()
        loadProperNouns()
        loadContractions()
        loadBigrams()
    }

    // MARK: - 加载词库

    private func loadBuiltIn() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt") else {
            NSLog("SmartEnglish ERROR: words.txt not found in bundle")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SmartEnglish ERROR: Failed to read words.txt")
            return
        }

        entries = content.components(separatedBy: .newlines).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let freq = Int(parts[1]) else { return nil }
            let word = String(parts[0]).lowercased()
            guard word.allSatisfy({ $0.isLetter && $0.isASCII }) else { return nil }
            if word.count < 2 && word != "a" && word != "i" { return nil }
            return (word: word, freq: freq)
        }

        entries.sort { $0.freq > $1.freq }
        NSLog("SmartEnglish: Loaded \(entries.count) words")
    }

    // MARK: - 查询

    func query(prefix: String, limit: Int = 9) -> [String] {
        guard !prefix.isEmpty else { return [] }

        var result: [String] = []
        var remainingLimit = limit

        // 1. 最高优先级：自定义片语（完全匹配 shortcut 时展开）
        if let expansion = UserDatabase.shared.getSnippet(prefix.lowercased()) {
            result.append(expansion)
            remainingLimit -= 1
        }

        var matches: [(word: String, score: Double)] = []
        var exactMatch = false

        for entry in entries {
            guard entry.word.hasPrefix(prefix) else { continue }

            if entry.word == prefix {
                exactMatch = true
                continue
            }

            let userBoost = Double(userFreqCache[entry.word] ?? 0) * 5000.0
            var score = Double(entry.freq) + userBoost

            // bigram 加权：如果前一个词已知，给匹配的下一个词强力 boost
            if !lastWord.isEmpty, let nextWords = bigrams[lastWord],
               let bigramFreq = nextWords[entry.word] {
                score += Double(bigramFreq) * 100.0
            }

            // 用户级 bigram 加权（权重远高于公共 bigram：×50000 vs ×100）
            if !lastWord.isEmpty {
                let userBigrams = getUserBigramsForCurrentContext()
                if let userBigramFreq = userBigrams[entry.word] {
                    score += Double(userBigramFreq) * 50000.0
                }
            }

            matches.append((entry.word, score))

            if matches.count >= remainingLimit * 5 { break }
        }

        matches.sort { $0.score > $1.score }
        result.append(contentsOf: matches.prefix(remainingLimit).map { $0.word })

        // 片语存在时，插入位置为 1（保持片语在首位）；否则为 0
        let insertPos = min(remainingLimit < limit ? 1 : 0, result.count)

        if exactMatch {
            result.insert(prefix, at: insertPos)
            if result.count > limit { result.removeLast() }
        }

        // 专有名词前缀补全：prefix >= 3 时，把 words.txt 里没有的专有名词 key 补进来
        if prefix.count >= 3 {
            for key in properNouns.keys {
                guard key.hasPrefix(prefix) && !result.contains(key) else { continue }
                if !entries.contains(where: { $0.word == key }) {
                    result.append(key)
                    if result.count >= limit { break }
                }
            }
        }

        // 缩写补全：输入完全匹配 contraction key 时处理
        if let contraction = contractions[prefix.lowercased()] {
            if ambiguousContractions.contains(prefix.lowercased()) {
                // 歧义词：固定插在原词之后（保证可见，不抢首位）
                // 旧逻辑"有空位才追加"会被前缀匹配填满的列表永久挤掉（如 cant → can't）
                result.removeAll { $0 == contraction }
                result.insert(contraction, at: min(insertPos + 1, result.count))
                if result.count > limit { result.removeLast() }
            } else {
                // 无歧义：放首位（但片语之后）
                result.removeAll { $0 == contraction }
                result.insert(contraction, at: insertPos)
                if result.count > limit { result.removeLast() }
            }
        }

        return result
    }

    // MARK: - 用户学习

    func recordSelection(word: String) {
        let cleanWord = word.lowercased()
        userFreqCache[cleanWord, default: 0] += 1
        UserDatabase.shared.recordWordSelection(word: cleanWord)

        // 记录用户级 bigram
        if !lastWord.isEmpty {
            UserDatabase.shared.recordBigram(prev: lastWord, next: cleanWord)
            // 清空缓存，下次 query 会重新加载
            lastWordBigramCache = nil
        }
    }

    /// 刷新缓存（SQLite 写入是即时的，此方法保留兼容接口）
    func flush() {
        // SQLite writes are immediate per-operation, nothing to flush
    }

    // MARK: - Bigram 上下文预测

    private func loadBigrams() {
        guard let url = Bundle.main.url(forResource: "bigrams", withExtension: "txt") else {
            NSLog("SmartEnglish: bigrams.txt not found in bundle (optional)")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SmartEnglish ERROR: Failed to read bigrams.txt")
            return
        }
        for line in content.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let freq = Int(parts[1]) else { continue }
            let words = parts[0].split(separator: " ", maxSplits: 1)
            guard words.count == 2 else { continue }
            let w1 = String(words[0])
            let w2 = String(words[1])
            bigrams[w1, default: [:]][w2] = freq
        }
        NSLog("SmartEnglish: Loaded bigrams for \(bigrams.count) prev-words")
    }

    /// 设置上下文词（用户上屏完一个词后调用）
    func setLastWord(_ word: String) {
        lastWord = word.lowercased().trimmingCharacters(in: .whitespaces)
        lastWordBigramCache = nil
    }

    /// 获取当前上下文的用户 bigram（带缓存）
    private func getUserBigramsForCurrentContext() -> [String: Int] {
        if let cache = lastWordBigramCache, cache.word == lastWord {
            return cache.bigrams
        }
        let bigrams = UserDatabase.shared.getUserBigrams(prev: lastWord)
        lastWordBigramCache = (lastWord, bigrams)
        return bigrams
    }

    // MARK: - 缩写补全

    private func loadContractions() {
        guard let url = Bundle.main.url(forResource: "contractions", withExtension: "txt") else {
            NSLog("SmartEnglish: contractions.txt not found in bundle (optional)")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SmartEnglish ERROR: Failed to read contractions.txt")
            return
        }
        for line in content.components(separatedBy: .newlines) {
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).lowercased()
            let value = String(parts[1])
            contractions[key] = value
        }
        NSLog("SmartEnglish: Loaded \(contractions.count) contractions")
    }

    // MARK: - 专有名词

    private func loadProperNouns() {
        guard let url = Bundle.main.url(forResource: "proper_nouns", withExtension: "txt") else {
            NSLog("SmartEnglish: proper_nouns.txt not found in bundle (optional)")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SmartEnglish ERROR: Failed to read proper_nouns.txt")
            return
        }
        var count = 0
        for line in content.components(separatedBy: .newlines) {
            let word = line.trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty else { continue }
            let key = word.lowercased()
            if key != word {
                properNouns[key] = word
                count += 1
            }
        }
        NSLog("SmartEnglish: Loaded \(count) proper nouns")
    }

    func properNounForm(for word: String) -> String? {
        return properNouns[word.lowercased()]
    }

    /// 查询自定义片语（供 InputController 判断选中项是否为片语）
    func getSnippet(for shortcut: String) -> String? {
        return UserDatabase.shared.getSnippet(shortcut)
    }
}
