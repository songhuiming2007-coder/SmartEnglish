import Foundation
import SQLite3

class UserDatabase {
    static let shared = UserDatabase()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        // 数据库路径
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let smartEnglishDir = appSupport.appendingPathComponent("SmartEnglish", isDirectory: true)
        try? FileManager.default.createDirectory(at: smartEnglishDir, withIntermediateDirectories: true)
        dbPath = smartEnglishDir.appendingPathComponent("userdata.sqlite").path

        openDatabase()
        createTables()
        migrateFromUserDefaultsIfNeeded()
        syncSnippetsFromJSON()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            NSLog("SmartEnglish: Failed to open database at \(dbPath)")
        } else {
            NSLog("SmartEnglish: Database opened at \(dbPath)")
        }
    }

    private func createTables() {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS user_word_freq (
            word TEXT PRIMARY KEY,
            freq INTEGER NOT NULL DEFAULT 0,
            last_used INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_user_word_freq ON user_word_freq(freq DESC);

        CREATE TABLE IF NOT EXISTS user_bigram (
            prev_word TEXT NOT NULL,
            next_word TEXT NOT NULL,
            freq INTEGER NOT NULL DEFAULT 0,
            last_used INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (prev_word, next_word)
        );
        CREATE INDEX IF NOT EXISTS idx_user_bigram_prev ON user_bigram(prev_word, freq DESC);

        CREATE TABLE IF NOT EXISTS user_snippet (
            shortcut TEXT PRIMARY KEY,
            expansion TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """

        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            NSLog("SmartEnglish: Failed to create tables: \(errmsg)")
        }
    }

    /// 从旧的 UserDefaults 数据迁移（一次性，迁移后设置标记）
    private func migrateFromUserDefaultsIfNeeded() {
        let migratedKey = "SmartEnglish_SQLiteMigrated_v1"
        if UserDefaults.standard.bool(forKey: migratedKey) { return }

        let oldUserFreqKey = "SmartEnglish_UserFreq"
        if let oldFreq = UserDefaults.standard.dictionary(forKey: oldUserFreqKey) as? [String: Int] {
            NSLog("SmartEnglish: Migrating \(oldFreq.count) words from UserDefaults to SQLite")

            // 使用事务批量插入
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            for (word, freq) in oldFreq {
                recordWordSelection(word: word, increment: freq)
            }
            sqlite3_exec(db, "COMMIT", nil, nil, nil)

            // 清理旧数据
            UserDefaults.standard.removeObject(forKey: oldUserFreqKey)
        }

        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    // MARK: - 用户词频

    func recordWordSelection(word: String, increment: Int = 1) {
        let sql = """
        INSERT INTO user_word_freq (word, freq, last_used)
        VALUES (?, ?, ?)
        ON CONFLICT(word) DO UPDATE SET
            freq = freq + ?,
            last_used = ?;
        """
        var stmt: OpaquePointer?
        let now = Int(Date().timeIntervalSince1970)

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(increment))
            sqlite3_bind_int(stmt, 3, Int32(now))
            sqlite3_bind_int(stmt, 4, Int32(increment))
            sqlite3_bind_int(stmt, 5, Int32(now))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getUserWordFreq(_ word: String) -> Int {
        let sql = "SELECT freq FROM user_word_freq WHERE word = ?"
        var stmt: OpaquePointer?
        var freq = 0

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                freq = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return freq
    }

    /// 批量加载所有用户词频到内存（用于查询时的高速访问）
    func loadAllUserWordFreq() -> [String: Int] {
        var result: [String: Int] = [:]
        let sql = "SELECT word, freq FROM user_word_freq"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let word = String(cString: sqlite3_column_text(stmt, 0))
                let freq = Int(sqlite3_column_int(stmt, 1))
                result[word] = freq
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - 用户 Bigram

    func recordBigram(prev: String, next: String) {
        let sql = """
        INSERT INTO user_bigram (prev_word, next_word, freq, last_used)
        VALUES (?, ?, 1, ?)
        ON CONFLICT(prev_word, next_word) DO UPDATE SET
            freq = freq + 1,
            last_used = ?;
        """
        var stmt: OpaquePointer?
        let now = Int(Date().timeIntervalSince1970)

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, prev, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, next, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(now))
            sqlite3_bind_int(stmt, 4, Int32(now))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getUserBigrams(prev: String) -> [String: Int] {
        var result: [String: Int] = [:]
        let sql = "SELECT next_word, freq FROM user_bigram WHERE prev_word = ?"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, prev, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let next = String(cString: sqlite3_column_text(stmt, 0))
                let freq = Int(sqlite3_column_int(stmt, 1))
                result[next] = freq
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - 自定义片语

    func setSnippet(shortcut: String, expansion: String, description: String? = nil) {
        let sql = """
        INSERT INTO user_snippet (shortcut, expansion, description, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(shortcut) DO UPDATE SET
            expansion = excluded.expansion,
            description = excluded.description,
            updated_at = excluded.updated_at;
        """
        var stmt: OpaquePointer?
        let now = Int(Date().timeIntervalSince1970)

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, shortcut.lowercased(), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, expansion, -1, SQLITE_TRANSIENT)
            if let desc = description {
                sqlite3_bind_text(stmt, 3, desc, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int(stmt, 4, Int32(now))
            sqlite3_bind_int(stmt, 5, Int32(now))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getSnippet(_ shortcut: String) -> String? {
        let sql = "SELECT expansion FROM user_snippet WHERE shortcut = ?"
        var stmt: OpaquePointer?
        var result: String? = nil

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, shortcut.lowercased(), -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func loadAllSnippets() -> [(shortcut: String, expansion: String, description: String?)] {
        var result: [(String, String, String?)] = []
        let sql = "SELECT shortcut, expansion, description FROM user_snippet ORDER BY shortcut"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let shortcut = String(cString: sqlite3_column_text(stmt, 0))
                let expansion = String(cString: sqlite3_column_text(stmt, 1))
                let desc: String? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 2))
                result.append((shortcut, expansion, desc))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func deleteSnippet(_ shortcut: String) {
        let sql = "DELETE FROM user_snippet WHERE shortcut = ?"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, shortcut.lowercased(), -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - JSON 片语同步

    func syncSnippetsFromJSON() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let jsonPath = appSupport.appendingPathComponent("SmartEnglish/snippets.json")

        guard FileManager.default.fileExists(atPath: jsonPath.path) else {
            // 文件不存在，创建一个带示例的初始文件
            let example: [String: String] = [
                "addr": "Your address here",
                "sig": "Your signature here",
                "em": "your@email.com"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: example, options: .prettyPrinted) {
                try? data.write(to: jsonPath)
                NSLog("SmartEnglish: Created example snippets.json")
            }
            return
        }

        guard let data = try? Data(contentsOf: jsonPath),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            NSLog("SmartEnglish: Failed to parse snippets.json")
            return
        }

        // 同步到 SQLite
        for (shortcut, expansion) in dict {
            setSnippet(shortcut: shortcut, expansion: expansion)
        }
        NSLog("SmartEnglish: Synced \(dict.count) snippets from JSON")
    }
}

// SQLite 字符串绑定的辅助常量
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
