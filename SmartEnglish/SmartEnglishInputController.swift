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

        // 数字键 1-9：选择对应候选词
        if let char = chars.first, char >= "1" && char <= "9" && !candidates.isEmpty && !composingText.isEmpty {
            let index = Int(String(char))! - 1
            if index < candidates.count {
                selectCandidate(at: index, client: client)
                return true
            }
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
        let word = candidates[index]

        client.insertText(
            word + " ",
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )

        dictionary.recordSelection(word: word)
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
