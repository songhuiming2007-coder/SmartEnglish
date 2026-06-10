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

    // ==================== 生命周期 ====================

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        shouldCapitalizeNext = true
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

    private func shouldDisableInContext(client: IMKTextInput) -> Bool {
        // 1. 检查输入字段属性（部分应用会标记密码字段）
        var rect = NSRect.zero
        let attrs = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        let secureKey = NSAttributedString.Key(rawValue: "NSTextInputSecureField")
        if let isSecure = attrs?[secureKey] as? Bool, isSecure {
            return true
        }

        // 2. 检查特定应用（终端、密码管理器等）
        let bundleId = client.bundleIdentifier() ?? ""
        if SmartEnglishInputController.blockedApps.contains(bundleId) {
            return true
        }

        return false
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


        // 字母键 a-z / A-Z
        if let char = chars.first, char.isLetter && char.isASCII {
            capsLockOn = event.modifierFlags.contains(.capsLock)
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
                        selectCandidate(at: index, client: client)
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

        // Space
        if keyCode == 49 {
            if !composingText.isEmpty {
                if !candidates.isEmpty {
                    selectCandidate(at: 0, client: client)
                } else {
                    commitComposing(client)
                }
                return true
            }
            return false
        }

        // Enter：上屏原始输入
        if keyCode == 36 {
            if !composingText.isEmpty {
                commitComposing(client)
                return true
            }
            return false
        }

        // Tab：选中第一个候选词
        if keyCode == 48 {
            if !composingText.isEmpty && !candidates.isEmpty {
                selectCandidate(at: 0, client: client)
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

    private func applyCasing(to word: String, composingText: String, client: IMKTextInput) -> String {
        let pattern = detectCasingPattern(composingText)

        switch pattern {
        case .allUppercase:
            return word.uppercased()

        case .firstUppercase:
            return word.prefix(1).uppercased() + word.dropFirst()

        case .allLowercase:
            // 句首大写 > 原样（专有名词已由候选列表注入，不再在这里强制转换）
            if shouldCapitalizeNext {
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

        for (i, raw) in rawList.enumerated() {
            let isSnippet = (i == 0 && snippetAtZero)
            let display: String
            if isSnippet {
                display = raw
            } else if shouldCapitalizeNext {
                display = raw.prefix(1).uppercased() + raw.dropFirst()
            } else {
                display = raw
            }
            if !isSnippet, let properForm = dictionary.properNounForm(for: raw),
               properForm != display {
                let properHasLowercase = properForm.contains(where: { $0.isLowercase })
                if properHasLowercase {
                    // 混合大小写（Mac、iPhone）：直接替换小写版，不显示小写
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

    /// 对候选词列表首字母大写（跳过首位片语）
    private func applyCapitalization(to words: [String], snippetAtZero: Bool = false) -> [String] {
        return words.enumerated().map { i, word in
            // 跳过首位的片语展开文本
            if i == 0 && snippetAtZero { return word }
            return word.prefix(1).uppercased() + word.dropFirst()
        }
    }

    private func selectCandidate(at index: Int, client: IMKTextInput) {
        guard index < candidates.count else { return }
        let rawWord = candidates[index]

        // 自定义片语：直接上屏，不走大小写转换和词频学习
        if index == 0, let snippet = dictionary.getSnippet(for: composingText.lowercased()), snippet == rawWord {
            client.insertText(
                rawWord + " ",
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            updateCapitalizationState(committedText: rawWord + " ")
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

        dictionary.recordSelection(word: rawWord)
        dictionary.setLastWord(rawWord)
        updateCapitalizationState(committedText: finalWord + " ")
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
