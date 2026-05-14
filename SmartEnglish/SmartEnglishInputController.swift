import Cocoa
import InputMethodKit

@objc(SmartEnglishInputController)
class SmartEnglishInputController: IMKInputController {

    // ==================== 状态 ====================
    private var composingText: String = ""
    private var candidates: [String] = []
    private let dictionary = WordDictionary.shared
    private lazy var candidateWindow = CandidateWindow.shared

    // ==================== 生命周期 ====================

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        reset()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposing(sender as? IMKTextInput)
        candidateWindow.hide()
        super.deactivateServer(sender)
    }

    // ==================== 按键处理 ====================

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        NSLog("SmartEnglish DEBUG: handle keyCode=%d chars=%@", event.keyCode, event.characters ?? "nil")

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

        // 数字键 1-9：选择对应候选词（必须在字母键之前，否则数字会被当作字母追加）
        if let char = chars.first, char >= "1" && char <= "9" && !candidates.isEmpty && !composingText.isEmpty {
            let index = Int(String(char))! - 1
            if index < candidates.count {
                selectCandidate(at: index, client: client)
                return true
            }
        }

        // 字母键 a-z / A-Z
        if let char = chars.first, char.isLetter && char.isASCII {
            composingText.append(char)
            updateMarkedText(client)
            updateCandidates(client)
            return true
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

    private func isAtSentenceStart(_ client: IMKTextInput) -> Bool {
        // TODO: client.string(from:actualRange:) 在部分应用中会 crash（空指针），
        // 暂时禁用句首检测，后续用 NSTextInputClient 协议方法重新实现
        return false
    }

    private func applyCasing(to word: String, composingText: String, client: IMKTextInput) -> String {
        let pattern = detectCasingPattern(composingText)

        switch pattern {
        case .allUppercase:
            return word.uppercased()

        case .firstUppercase:
            return word.prefix(1).uppercased() + word.dropFirst()

        case .allLowercase:
            if let properForm = dictionary.properNounForm(for: word) {
                return properForm
            }
            if isAtSentenceStart(client) {
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
            var cursorRect = NSRect.zero
            let _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorRect)
            candidateWindow.show(candidates: candidates, cursorRect: cursorRect)
        }
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
        reset()
        candidateWindow.hide()
    }

    private func commitComposing(_ client: IMKTextInput?) {
        guard !composingText.isEmpty, let client = client else { return }
        client.insertText(
            composingText,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
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

    private func reset() {
        composingText = ""
        candidates = []
    }
}
