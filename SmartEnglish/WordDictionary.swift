import Foundation

class WordDictionary {
    static let shared = WordDictionary()

    private var entries: [(word: String, freq: Int)] = []
    private var userFreq: [String: Int] = [:]
    private var properNouns: [String: String] = [:]  // lowercase -> standard form
    private let userDefaultsKey = "SmartEnglish_UserFreq"

    private init() {
        loadBuiltIn()
        loadUserFreq()
        loadProperNouns()
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

        var matches: [(word: String, score: Double)] = []
        var exactMatch = false

        for entry in entries {
            guard entry.word.hasPrefix(prefix) else { continue }

            if entry.word == prefix {
                exactMatch = true
                continue
            }

            let userBoost = Double(userFreq[entry.word] ?? 0) * 5000.0
            let score = Double(entry.freq) + userBoost
            matches.append((entry.word, score))

            if matches.count >= limit * 5 { break }
        }

        matches.sort { $0.score > $1.score }
        var result = Array(matches.prefix(limit).map { $0.word })

        if exactMatch {
            result.insert(prefix, at: 0)
            if result.count > limit { result.removeLast() }
        }

        return result
    }

    // MARK: - 用户学习

    func recordSelection(word: String) {
        userFreq[word, default: 0] += 1
        saveUserFreq()
    }

    private func loadUserFreq() {
        userFreq = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Int] ?? [:]
    }

    private func saveUserFreq() {
        UserDefaults.standard.set(userFreq, forKey: userDefaultsKey)
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
}
