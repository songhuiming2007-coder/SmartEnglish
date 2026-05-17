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

    // ==================== 生命周期 ====================

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        shouldCapitalizeNext = true
        reset()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposing(sender as? IMKTextInput)
        candidateWindow.hide()
        dictionary.flush()
        super.deactivateServer(sender)
    }

    // ==================== 不打扰模式 ====================

    private static let blockedApps: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
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
            NSLog("SmartEnglish: Disabled — secure field detected")
            return true
        }

        // 2. 检查特定应用（终端、密码管理器等）
        let bundleId = client.bundleIdentifier() ?? ""
        if SmartEnglishInputController.blockedApps.contains(bundleId) {
            NSLog("SmartEnglish: Disabled — blocked app: %@", bundleId)
            return true
        }

        return false
    }

    // ==================== 按键处理 ====================

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        NSLog("SmartEnglish DEBUG: handle keyCode=%d chars=%@", event.keyCode, event.characters ?? "nil")

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
            // 优先级：专有名词 > 句首大写 > 原样
            if let properForm = dictionary.properNounForm(for: word) {
                return properForm
            }
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

        candidates = dictionary.query(prefix: composingText.lowercased(), limit: 9)

        if candidates.isEmpty {
            candidateWindow.hide()
        } else {
            // 句首大写：对候选词应用大写（不修改原始 candidates，只影响显示）
            var displayCandidates = candidates
            if shouldCapitalizeNext {
                displayCandidates = applyCapitalization(to: candidates)
            }
            var cursorRect = NSRect.zero
            let _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorRect)
            candidateWindow.show(candidates: displayCandidates, cursorRect: cursorRect)
        }
    }

    /// 对候选词列表首字母大写
    private func applyCapitalization(to words: [String]) -> [String] {
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    private func selectCandidate(at index: Int, client: IMKTextInput) {
        guard index < candidates.count else { return }
        let rawWord = candidates[index]
        let finalWord = applyCasing(to: rawWord, composingText: composingText, client: client)

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
