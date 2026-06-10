import Cocoa
import InputMethodKit

@objc(SmartEnglishInputController)
class SmartEnglishInputController: IMKInputController {

    // ==================== 状态 ====================
    private var composingText: String = ""
    private var candidates: [String] = []
    private let dictionary = WordDictionary.shared
    private lazy var candidateWindow = CandidateWindow.shared
    private var shouldCapitalizeNext: Bool = true
    private var lastCommittedText: String = ""
    /// 最近一次字母键按下时 Caps Lock 是否亮灯（用于消歧单个大写字母：Shift→Hello，Caps Lock→HELLO）
    private var capsLockOn: Bool = false
    /// 上一次提交是否以自动空格结尾（智能空格：紧跟的标点会吞掉这个空格）
    private var pendingAutoSpace: Bool = false
    /// 当前词起始位置是否为句首（词首字母按下时从真实文档上下文捕获）
    private var sentenceStart: Bool = true
    /// 会触发智能空格回退的标点（出现在自动空格后时，标点前移吞掉空格）
    private static let smartPunctuation: Set<Character> = [".", ",", "?", "!", ";", ":", ")", "]", "}"]

    // ==================== 生命周期 ====================

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        shouldCapitalizeNext = true
        sentenceStart = true
        pendingAutoSpace = false
        reset()

        // 接线：鼠标点击候选词
        guard let client = sender as? IMKTextInput else { return }
        candidateWindow.onCandidateSelected = { [weak self, weak client] index in
            guard let self, let client else { return }
            self.selectCandidate(at: index, client: client)
        }
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposing(sender as? IMKTextInput)
        candidateWindow.onCandidateSelected = nil
        candidateWindow.hide()
        dictionary.flush()
        super.deactivateServer(sender)
    }

    // ==================== 不打扰模式 ====================

    private static let blockedApps: Set<String> = [
        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable",
        "org.alacritty",
        "co.zeit.hyper",
        // Editors & IDEs
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",       // Cursor
        "com.sublimetext.4",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "org.macromates.TextMate",
        "dev.zed.Zed",
        "org.vim.MacVim",
        // JetBrains IDEs
        "com.jetbrains.intellij",              // IntelliJ IDEA
        "com.jetbrains.intellij.ce",           // IntelliJ CE
        "com.jetbrains.pycharm",               // PyCharm
        "com.jetbrains.pycharm.ce",            // PyCharm CE
        "com.jetbrains.WebStorm",              // WebStorm
        "com.jetbrains.CLion",                 // CLion
        "com.jetbrains.Rider",                 // Rider
        "com.jetbrains.GoLand",                // GoLand
        "com.jetbrains.RubyMine",              // RubyMine
        "com.jetbrains.PhpStorm",              // PhpStorm
        "com.jetbrains.DataGrip",              // DataGrip
        // Password managers
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
    ]

    /// 用户自定义 DND 应用列表（~/Library/Application Support/SmartEnglish/blocked_apps.json，
    /// 内容为 bundle ID 字符串数组；修改后需切换一次输入法生效）
    private static let userBlockedApps: Set<String> = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("SmartEnglish/blocked_apps.json")
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        NSLog("SmartEnglish: Loaded \(list.count) user-blocked apps")
        return Set(list)
    }()

    private func shouldDisableInContext(client: IMKTextInput) -> Bool {
        // 1. 检查输入字段属性（部分应用会标记密码字段）
        var rect = NSRect.zero
        let attrs = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        let secureKey = NSAttributedString.Key(rawValue: "NSTextInputSecureField")
        if let isSecure = attrs?[secureKey] as? Bool, isSecure {
            return true
        }

        // 2. 检查特定应用（终端、密码管理器等）+ 用户自定义列表
        let bundleId = client.bundleIdentifier() ?? ""
        if SmartEnglishInputController.blockedApps.contains(bundleId) ||
           SmartEnglishInputController.userBlockedApps.contains(bundleId) {
            return true
        }

        return false
    }

    // ==================== 输入法菜单 ====================

    override func menu() -> NSMenu! {
        let menu = NSMenu()

        let snippets = NSMenuItem(title: "Edit Snippets…", action: #selector(openSnippetsFile(_:)), keyEquivalent: "")
        snippets.target = self
        menu.addItem(snippets)

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        return menu
    }

    @objc private func openSnippetsFile(_ sender: Any?) {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("SmartEnglish/snippets.json")
        NSWorkspace.shared.open(url)
    }

    /// 只打开 Releases 页面，不做任何后台网络请求（隐私承诺：应用本身零联网）
    @objc private func checkForUpdates(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://github.com/songhuiming2007-coder/SmartEnglish/releases/latest")!)
    }

    // ==================== 按键处理 ====================

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        // 不打扰模式：密码框/终端等场景，所有按键透传
        if shouldDisableInContext(client: client) {
            if !composingText.isEmpty {
                commitComposing(client)
            }
            return false
        }

        let keyCode = event.keyCode
        let chars = event.characters ?? ""
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 带修饰键：不拦截，先上屏当前文本
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            if !composingText.isEmpty {
                commitComposing(client)
            }
            return false
        }

        // 自动空格标记：只对紧随其后的标点键生效，任何其他按键都清除
        let hadAutoSpace = pendingAutoSpace
        pendingAutoSpace = false

        // 字母键 a-z / A-Z
        if let char = chars.first, char.isLetter && char.isASCII {
            capsLockOn = event.modifierFlags.contains(.capsLock)
            if composingText.isEmpty {
                // 词首：读真实文档上下文判断句首（点击换位、切输入框、Enter 换行都准确）
                sentenceStart = sentenceStartFromContext(client) ?? shouldCapitalizeNext
            }
            composingText.append(char)
            updateMarkedText(client)
            updateCandidates(client)
            return true
        }

        // 词中撇号：并入 composing，支持直接打 can't、I'm 等缩写
        if let char = chars.first, char == "'", !composingText.isEmpty {
            composingText.append(char)
            updateMarkedText(client)
            updateCandidates(client)
            return true
        }

        // 数字键 0-9：composing 状态下特殊处理
        if let char = chars.first, char.isNumber {
            if !composingText.isEmpty {
                // 有候选词且按 1-9：选词
                if !candidates.isEmpty && char >= "1" && char <= "9" {
                    let index = Int(String(char))! - 1
                    if index < candidates.count {
                        selectCandidate(at: index, client: client, explicit: true)
                        return true
                    }
                }
                // 没有候选词或按 0：先上屏当前 composing，再让数字透传
                commitComposing(client)
                return false
            }
            // 非 composing 状态：数字透传
            return false
        }

        // Backspace
        if keyCode == 51 {
            if !composingText.isEmpty {
                composingText.removeLast()
                if composingText.isEmpty {
                    clearComposing(client)
                } else {
                    updateMarkedText(client)
                    updateCandidates(client)
                }
                return true
            }
            return false
        }

        // Space：选中当前高亮候选词（方向键/鼠标悬停可移动高亮，默认为 0）
        if keyCode == 49 {
            if !composingText.isEmpty {
                if !candidates.isEmpty {
                    let index = min(candidateWindow.selectedIndex, candidates.count - 1)
                    // 移动过高亮 = 主动选择；停在首位 = 默认接受
                    selectCandidate(at: index, client: client, explicit: index != 0)
                    return true
                }
                // 无候选词：上屏原文，空格本身透传（否则空格被吞）
                commitComposing(client)
                return false
            }
            return false
        }

        // Enter：上屏原始输入；换行后下一词按句首处理（fallback 状态）
        if keyCode == 36 {
            let hadComposing = !composingText.isEmpty
            if hadComposing { commitComposing(client) }
            shouldCapitalizeNext = true
            return hadComposing
        }

        // Tab：接受第一个候选词（默认接受，学习权重低于主动选择）
        if keyCode == 48 {
            if !composingText.isEmpty && !candidates.isEmpty {
                selectCandidate(at: 0, client: client, explicit: false)
                return true
            }
            return false
        }

        // 方向键：移动候选词选中状态
        if (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126) {
            if !composingText.isEmpty && !candidates.isEmpty {
                let delta = (keyCode == 123 || keyCode == 125) ? -1 : 1  // 左/下 -1, 右/上 +1
                let newIndex = (candidateWindow.selectedIndex + delta + candidates.count) % candidates.count
                candidateWindow.selectedIndex = newIndex
                return true
            }
        }

        // Escape：取消输入
        if keyCode == 53 {
            if !composingText.isEmpty {
                clearComposing(client)
                return true
            }
            return false
        }

        // 智能空格：选词自动加的空格后紧跟标点 → 标点前移吞掉空格（"hello ." → "hello. "）
        if hadAutoSpace, composingText.isEmpty, let ch = chars.first,
           SmartEnglishInputController.smartPunctuation.contains(ch) {
            let sel = client.selectedRange()
            if sel.location != NSNotFound, sel.location > 0,
               let before = client.attributedSubstring(from: NSRange(location: sel.location - 1, length: 1))?.string,
               before == " " {
                client.insertText(
                    "\(ch) ",
                    replacementRange: NSRange(location: sel.location - 1, length: 1)
                )
                pendingAutoSpace = true  // 重新加的空格也是自动空格，标点可连打（"word!?"）
                shouldCapitalizeNext = "?!.".contains(ch)
                return true
            }
        }

        // 其他字符（标点等）：先上屏当前文本，再透传
        if !composingText.isEmpty {
            commitComposing(client)
        }
        // 句末标点后应大写下一个词
        if let ch = chars.first, [".", "?", "!"].contains(String(ch)) {
            shouldCapitalizeNext = true
        }
        return false
    }

    // ==================== 大写处理 ====================

    private enum CasingPattern {
        case allUppercase       // "ENG"
        case firstUppercase     // "Eng"
        case allLowercase       // "eng"
    }

    private func detectCasingPattern(_ text: String) -> CasingPattern {
        guard !text.isEmpty else { return .allLowercase }

        let first = text.first!
        let hasLower = text.contains(where: { $0.isLowercase })

        if first.isUppercase {
            if !hasLower {
                // 单个大写字母有歧义：Caps Lock 亮灯 → 全大写；Shift 打出的 → 首字母大写
                if text.count == 1 {
                    return capsLockOn ? .allUppercase : .firstUppercase
                }
                return .allUppercase
            }
            let rest = text.dropFirst()
            if rest.allSatisfy({ $0.isLowercase || !$0.isLetter }) {
                return .firstUppercase
            }
            return .allUppercase
        } else {
            if text.contains(where: { $0.isUppercase }) {
                return .allUppercase
            }
            return .allLowercase
        }
    }

    /// 从真实文档读取光标前文本判断句首；客户端不支持时返回 nil（调用方退回内部状态）
    /// 只在 composing 为空时调用（marked text 激活期间光标前是 composing 内容，会误判）
    private func sentenceStartFromContext(_ client: IMKTextInput) -> Bool? {
        let sel = client.selectedRange()
        guard sel.location != NSNotFound else { return nil }
        if sel.location == 0 { return true }

        let len = min(16, sel.location)
        guard let text = client.attributedSubstring(
            from: NSRange(location: sel.location - len, length: len)
        )?.string, !text.isEmpty else { return nil }

        for ch in text.reversed() {
            if ch == " " || ch == "\t" { continue }
            if ch == "\n" || ch == "\r" { return true }
            if ch == "." || ch == "?" || ch == "!" { return true }
            return false
        }
        // 窗口内全是空白：到达文档头则是句首，否则看不到更早内容，放弃判断
        return sel.location - len == 0 ? true : nil
    }

    private func applyCasing(to word: String, composingText: String, client: IMKTextInput) -> String {
        let pattern = detectCasingPattern(composingText)

        switch pattern {
        case .allUppercase:
            return word.uppercased()

        case .firstUppercase:
            return word.prefix(1).uppercased() + word.dropFirst()

        case .allLowercase:
            // 句首大写 > 原样（专有名词已由候选列表注入，不再在这里强制转换）
            if sentenceStart {
                return word.prefix(1).uppercased() + word.dropFirst()
            }
            return word
        }
    }

    // ==================== 内部方法 ====================

    private func updateMarkedText(_ client: IMKTextInput) {
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.textColor
        ]
        let attrStr = NSAttributedString(string: composingText, attributes: attrs)
        client.setMarkedText(
            attrStr,
            selectionRange: NSRange(location: composingText.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    private func updateCandidates(_ client: IMKTextInput) {
        guard !composingText.isEmpty else {
            candidateWindow.hide()
            candidates = []
            return
        }

        let rawList = dictionary.query(prefix: composingText.lowercased(), limit: 9)

        if rawList.isEmpty {
            candidates = []
            candidateWindow.hide()
            return
        }

        // 构建 (raw, display) 对，注入专有名词变体
        let snippetAtZero = dictionary.getSnippet(for: composingText.lowercased()) != nil
        var pairs: [(raw: String, display: String)] = []

        let casing = detectCasingPattern(composingText)
        for (i, raw) in rawList.enumerated() {
            let isSnippet = (i == 0 && snippetAtZero)
            let display: String
            if isSnippet {
                display = raw
            } else {
                // 预览最终上屏形式（所见即所得：打 "Hel" 显示 "Hello" 而不是 "hello"）
                switch casing {
                case .allUppercase:
                    display = raw.uppercased()
                case .firstUppercase:
                    display = raw.prefix(1).uppercased() + raw.dropFirst()
                case .allLowercase:
                    display = sentenceStart ? raw.prefix(1).uppercased() + raw.dropFirst() : raw
                }
            }
            if !isSnippet, let properForm = dictionary.properNounForm(for: raw),
               properForm != display {
                let properHasLowercase = properForm.contains(where: { $0.isLowercase })
                if properHasLowercase || raw == "i" {
                    // 混合大小写（Mac、iPhone）和裸 i：直接替换，小写形式不是合法写法
                    pairs.append((raw: properForm, display: properForm))
                } else {
                    // 纯大写（IT、IP）：两个都显示，小写在前
                    pairs.append((raw, display))
                    pairs.append((raw: properForm, display: properForm))
                }
            } else {
                pairs.append((raw, display))
            }
        }

        // 截断到 9 个
        if pairs.count > 9 { pairs = Array(pairs.prefix(9)) }

        candidates = pairs.map { $0.raw }
        let displayCandidates = pairs.map { $0.display }

        var cursorRect = NSRect.zero
        let _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorRect)
        candidateWindow.show(candidates: displayCandidates, cursorRect: cursorRect)
    }

    private func selectCandidate(at index: Int, client: IMKTextInput, explicit: Bool = true) {
        guard index < candidates.count else { return }
        let rawWord = candidates[index]

        // 自定义片语：直接上屏，不走大小写转换和词频学习
        if index == 0, let snippet = dictionary.getSnippet(for: composingText.lowercased()), snippet == rawWord {
            client.insertText(
                rawWord + " ",
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            updateCapitalizationState(committedText: rawWord + " ")
            pendingAutoSpace = true
            reset()
            candidateWindow.hide()
            return
        }

        // 专有名词形式（如 "IT"）：直接上屏，不走大小写转换
        let finalWord: String
        if let properForm = dictionary.properNounForm(for: rawWord.lowercased()),
           rawWord == properForm {
            finalWord = rawWord
        } else {
            finalWord = applyCasing(to: rawWord, composingText: composingText, client: client)
        }

        client.insertText(
            finalWord + " ",
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )

        // 主动选择（数字键/鼠标/移动过高亮）权重 2，默认接受（空格/Tab 选首位）权重 1
        dictionary.recordSelection(word: rawWord, weight: explicit ? 2 : 1)
        dictionary.setLastWord(rawWord)
        updateCapitalizationState(committedText: finalWord + " ")
        pendingAutoSpace = true
        reset()
        candidateWindow.hide()
    }

    private func commitComposing(_ client: IMKTextInput?) {
        guard !composingText.isEmpty, let client = client else { return }
        client.insertText(
            composingText,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        updateCapitalizationState(committedText: composingText)
        pendingAutoSpace = false
        reset()
        candidateWindow.hide()
    }

    private func clearComposing(_ client: IMKTextInput) {
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        reset()
        candidateWindow.hide()
    }

    /// 上屏后更新句首大写状态
    private func updateCapitalizationState(committedText: String) {
        lastCommittedText = committedText
        let trimmed = committedText.trimmingCharacters(in: .whitespaces)

        // 检查是否以句号/问号/感叹号结尾
        if let last = trimmed.last, [".", "?", "!"].contains(String(last)) {
            shouldCapitalizeNext = true
        } else if committedText.hasSuffix(". ") ||
                  committedText.hasSuffix("? ") ||
                  committedText.hasSuffix("! ") {
            shouldCapitalizeNext = true
        } else if committedText.contains("\n") {
            shouldCapitalizeNext = true
        } else {
            shouldCapitalizeNext = false
        }
    }

    private func reset() {
        composingText = ""
        candidates = []
    }
}
