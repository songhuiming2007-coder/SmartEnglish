# SmartEnglish — macOS 英文预测输入法 · Claude Code 全套开发 Prompt

> 将此文档完整粘贴给 Claude Code 作为项目启动 prompt。
> 开发者环境：macOS + Xcode 26.5（仅用命令行构建，不打开 Xcode GUI）+ VS Code + Terminal

---

## 项目概述

开发一个 macOS 原生输入法 App，名为 **SmartEnglish**。功能：用户在任何应用中输入英文时，输入法会像 iPhone 键盘或 Mac 中文拼音输入法一样，在光标位置弹出候选词窗口，用户可点击/按键选择候选词完成补全。

**核心体验目标：** 用户切换到 SmartEnglish 输入法后，打英文字母会实时出现候选词（前缀匹配 + 词频排序），选中即补全；不选则按空格/回车直接上屏原始输入。与系统原生中文输入法的交互体验完全一致。

**环境信息：**
- macOS + Xcode 26.5（已安装，但不打开 GUI，全程用 xcodebuild 命令行构建）
- 开发者用 VS Code 编辑代码，用 Terminal / Claude Code 执行命令
- 不需要 Apple Developer 付费账号，用本地 ad-hoc 签名即可

---

## 技术栈

- **语言：** Swift（使用 Xcode 26.5 自带的 Swift 版本）
- **框架：** InputMethodKit (IMKit)、AppKit
- **候选窗口：** 自定义 NSPanel（**不要用 IMKCandidates**——它在 macOS 26 上有严重的 LiquidGlass 渲染 bug：白字透明背景，连 Apple 自己的 NumberInput 示例都回避它。所有成熟第三方输入法都自己实现候选窗口。）
- **构建：** Xcode project + `xcodebuild` 命令行（不打开 Xcode GUI）
- **最低支持：** macOS 13 Ventura
- **词库：** 内嵌约 50,000 词频表（基于 Google Trillion Word Corpus / Peter Norvig 词频数据）

---

## 第一步：创建 Xcode 项目（命令行方式）

由于输入法的 .app bundle 结构比较特殊，我们需要一个 .xcodeproj。但不需要打开 Xcode GUI，用以下脚本自动生成：

### 方案：用 `xcodegen` 或手动创建

**推荐方案：直接手写 project.pbxproj 太复杂，改用一个 setup 脚本调用 `xcodebuild` 从模板生成。**

**实际操作：用一个 Swift Package 辅助工具 XcodeGen 来生成 .xcodeproj**

```bash
# 安装 XcodeGen（如果没装 Homebrew，先装 Homebrew）
brew install xcodegen
```

然后在项目根目录创建 `project.yml`，XcodeGen 会根据它生成 `.xcodeproj`：

```yaml
name: SmartEnglish
options:
  bundleIdPrefix: com.songhuiming
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "26.5"

settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.songhuiming.inputmethod.SmartEnglish
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    SWIFT_VERSION: "5.0"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGNING_REQUIRED: "NO"
    PRODUCT_NAME: SmartEnglish

targets:
  SmartEnglish:
    type: application
    platform: macOS
    sources:
      - path: Sources
        type: group
    resources:
      - path: Resources
        type: group
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.songhuiming.inputmethod.SmartEnglish
        INFOPLIST_FILE: Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Resources/SmartEnglish.entitlements
        CODE_SIGN_IDENTITY: "-"
        PRODUCT_NAME: SmartEnglish
        COMBINE_HIDPI_IMAGES: YES
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
```

```bash
# 生成 Xcode 项目
cd ~/Projects/SmartEnglish  # 你的项目目录
xcodegen generate

# 构建
xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release build

# 安装到输入法目录
cp -R ~/Library/Developer/Xcode/DerivedData/SmartEnglish-*/Build/Products/Release/SmartEnglish.app \
      ~/Library/Input\ Methods/SmartEnglish.app
```

---

## 项目文件结构

```
SmartEnglish/
├── project.yml                           # XcodeGen 项目描述文件
├── Sources/
│   ├── main.swift                        # 入口，手动创建 NSApplication
│   ├── AppDelegate.swift                 # 初始化 IMKServer
│   ├── SmartEnglishInputController.swift # 核心：继承 IMKInputController
│   ├── CandidateWindow.swift             # 自定义 NSPanel 候选窗口
│   ├── CandidateView.swift               # 候选词 UI 视图
│   ├── WordDictionary.swift              # 词库加载、前缀匹配、词频排序
│   └── UserFrequency.swift               # 用户词频学习（记住用户常选的词）
├── Resources/
│   ├── Info.plist                         # 输入法核心配置
│   ├── SmartEnglish.entitlements          # Sandbox 权限
│   ├── words.txt                          # 词频表：每行 "word\tfrequency"
│   └── main.tiff                          # 菜单栏图标（16x16 + 32x32）
├── scripts/
│   ├── build.sh                           # 一键构建
│   ├── install.sh                         # 一键安装
│   ├── dev.sh                             # 构建+安装+重启 一条龙
│   └── prepare_wordlist.py                # 下载并清洗词频表
├── Makefile                               # make build / make install / make dev
└── README.md
```

---

## Info.plist 完整配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>

    <key>CFBundleName</key>
    <string>SmartEnglish</string>

    <key>CFBundleDisplayName</key>
    <string>SmartEnglish</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>

    <!-- NSConnection 名称——必须是这个格式，否则 Sandbox 下连接失败 -->
    <key>InputMethodConnectionName</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)_Connection</string>

    <!-- 输入法控制器类名，必须含模块前缀 -->
    <key>InputMethodServerControllerClass</key>
    <string>$(PRODUCT_MODULE_NAME).SmartEnglishInputController</string>

    <!-- 主类 -->
    <key>NSPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).NSManualApplication</string>

    <!-- 后台应用——输入法不能出现在 Dock 栏 -->
    <key>LSBackgroundOnly</key>
    <true/>

    <!-- 字符集：拉丁字母 -->
    <key>tsInputMethodCharacterRepertoireKey</key>
    <array>
        <string>Latn</string>
    </array>

    <!-- 菜单栏图标 -->
    <key>tsInputMethodIconFileKey</key>
    <string>main.tiff</string>

    <!-- 输入源注册信息 -->
    <key>ComponentInputModeDict</key>
    <dict>
        <key>tsInputModeListKey</key>
        <dict>
            <key>com.songhuiming.inputmethod.SmartEnglish</key>
            <dict>
                <key>TISIntendedLanguage</key>
                <string>en</string>
                <key>TISInputSourceID</key>
                <string>com.songhuiming.inputmethod.SmartEnglish</string>
                <key>tsInputModeDefaultStateKey</key>
                <true/>
                <key>tsInputModeScriptKey</key>
                <string>smRoman</string>
                <key>tsInputModePrimaryInScriptKey</key>
                <true/>
                <key>tsInputModeIsVisibleKey</key>
                <true/>
                <key>tsInputModeKeyEquivalentModifiersKey</key>
                <integer>0</integer>
                <key>tsInputModeKeyEquivalentKey</key>
                <string></string>
                <key>tsInputModeMenuIconFileKey</key>
                <string>main.tiff</string>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

---

## Entitlements（Sandbox 配置）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.temporary-exception.mach-register.global-name</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)_Connection</string>
    <key>com.apple.security.temporary-exception.shared-preference.read-only</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</dict>
</plist>
```

---

## 核心源码

### Sources/main.swift

```swift
import Cocoa
import InputMethodKit

/// 自定义 NSApplication 子类，手动设置 delegate
/// 输入法不走标准的 @main / NSApplicationMain 启动流程
class NSManualApplication: NSApplication {
    private let appDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = appDelegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// 启动应用
let app = NSManualApplication.shared
app.run()
```

### Sources/AppDelegate.swift

```swift
import Cocoa
import InputMethodKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            NSLog("SmartEnglish ERROR: InputMethodConnectionName not found in Info.plist")
            return
        }
        server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("SmartEnglish: Server started, connection=\(connectionName)")
    }
}
```

### Sources/SmartEnglishInputController.swift — 核心

```swift
import Cocoa
import InputMethodKit

@objc(SmartEnglishInputController)
class SmartEnglishInputController: IMKInputController {

    // ==================== 状态 ====================
    private var composingText: String = ""    // 当前输入的字母序列
    private var candidates: [String] = []     // 当前候选词列表
    private let dictionary = WordDictionary.shared
    private lazy var candidateWindow = CandidateWindow.shared

    // ==================== 生命周期 ====================

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        reset()
        NSLog("SmartEnglish: activateServer")
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposing(sender as? IMKTextInput)
        candidateWindow.hide()
        super.deactivateServer(sender)
        NSLog("SmartEnglish: deactivateServer")
    }

    // ==================== 按键处理（核心入口）====================

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        let keyCode = event.keyCode
        let chars = event.characters ?? ""
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ---- 带修饰键（Cmd/Ctrl/Option）：不拦截，先上屏当前文本 ----
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            if !composingText.isEmpty {
                commitComposing(client)
            }
            return false
        }

        // ---- 字母键 a-z / A-Z ----
        if let char = chars.first, char.isLetter && char.isASCII {
            composingText.append(char)
            updateMarkedText(client)
            updateCandidates(client)
            return true
        }

        // ---- Backspace（退格）----
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

        // ---- 数字键 1-9：选择对应候选词 ----
        if let char = chars.first, char >= "1" && char <= "9" && !candidates.isEmpty && !composingText.isEmpty {
            let index = Int(String(char))! - 1
            if index < candidates.count {
                selectCandidate(at: index, client: client)
                return true
            }
        }

        // ---- Space（空格）----
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

        // ---- Enter（回车）：上屏原始输入 ----
        if keyCode == 36 {
            if !composingText.isEmpty {
                commitComposing(client)
                return true
            }
            return false
        }

        // ---- Tab：选中第一个候选词 ----
        if keyCode == 48 {
            if !composingText.isEmpty && !candidates.isEmpty {
                selectCandidate(at: 0, client: client)
                return true
            }
            return false
        }

        // ---- Escape：取消输入 ----
        if keyCode == 53 {
            if !composingText.isEmpty {
                clearComposing(client)
                return true
            }
            return false
        }

        // ---- 其他字符（标点等）：先上屏当前文本，再透传 ----
        if !composingText.isEmpty {
            commitComposing(client)
        }
        return false
    }

    // ==================== 内部方法 ====================

    /// 更新应用中的 marked text（带下划线的预输入文本）
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

    /// 查询词库并更新候选窗口
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
            // 获取光标屏幕坐标
            var cursorRect = NSRect.zero
            let _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorRect)
            candidateWindow.show(candidates: candidates, cursorRect: cursorRect)
        }
    }

    /// 选中候选词，提交到应用
    private func selectCandidate(at index: Int, client: IMKTextInput) {
        guard index < candidates.count else { return }
        let word = candidates[index]

        // 插入候选词 + 空格
        client.insertText(
            word + " ",
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )

        // 记录用户选择
        dictionary.recordSelection(word: word)
        reset()
        candidateWindow.hide()
    }

    /// 将原始输入文本直接上屏
    private func commitComposing(_ client: IMKTextInput?) {
        guard !composingText.isEmpty, let client = client else { return }
        client.insertText(
            composingText,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        reset()
        candidateWindow.hide()
    }

    /// 清空输入（ESC 等场景）
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
```

### Sources/CandidateWindow.swift — 自定义候选窗口

```swift
import Cocoa

class CandidateWindow {
    static let shared = CandidateWindow()

    private let panel: NSPanel
    private let candidateView: CandidateView
    /// 用于通知 InputController 用户点击了哪个候选词
    var onCandidateSelected: ((Int) -> Void)?

    private init() {
        candidateView = CandidateView()

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 32),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = candidateView

        // 鼠标点击选词回调
        candidateView.onClicked = { [weak self] index in
            self?.onCandidateSelected?(index)
        }
    }

    func show(candidates: [String], cursorRect: NSRect) {
        candidateView.update(candidates: candidates)

        let size = candidateView.idealSize()
        panel.setContentSize(size)

        // 定位到光标下方
        var origin = cursorRect.origin
        origin.y -= size.height + 4

        // 确保不超出屏幕
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            if origin.x + size.width > frame.maxX {
                origin.x = frame.maxX - size.width
            }
            if origin.x < frame.minX {
                origin.x = frame.minX
            }
            if origin.y < frame.minY {
                // 空间不够，改到光标上方
                origin.y = cursorRect.maxY + 4
            }
        }

        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}
```

### Sources/CandidateView.swift — 候选词 UI

```swift
import Cocoa

class CandidateView: NSView {
    private var candidates: [String] = []
    private var itemRects: [NSRect] = []   // 每个候选词的点击区域
    private var hoveredIndex: Int = -1      // 鼠标悬停的候选词
    var onClicked: ((Int) -> Void)?

    private let font = NSFont.systemFont(ofSize: 14)
    private let indexFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let hPadding: CGFloat = 10
    private let itemSpacing: CGFloat = 14
    private let vPadding: CGFloat = 5

    // 允许鼠标事件
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        // 添加鼠标追踪
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(candidates: [String]) {
        self.candidates = candidates
        self.hoveredIndex = -1
        needsDisplay = true
    }

    func idealSize() -> NSSize {
        var totalWidth: CGFloat = hPadding
        for (i, word) in candidates.enumerated() {
            let label = "\(i + 1). \(word)"
            let labelSize = (label as NSString).size(withAttributes: [.font: font])
            totalWidth += labelSize.width + itemSpacing
        }
        totalWidth += hPadding
        return NSSize(width: max(totalWidth, 80), height: 28)
    }

    override func draw(_ dirtyRect: NSRect) {
        // 背景
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
        bgPath.fill()
        NSColor.separatorColor.setStroke()
        bgPath.lineWidth = 0.5
        bgPath.stroke()

        // 绘制候选词
        var x: CGFloat = hPadding
        let y: CGFloat = vPadding
        itemRects = []

        for (i, word) in candidates.enumerated() {
            let indexStr = "\(i + 1)."
            let indexAttrs: [NSAttributedString.Key: Any] = [
                .font: indexFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let wordAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: (i == hoveredIndex) ? NSColor.selectedTextColor : NSColor.labelColor
            ]

            let indexSize = (indexStr as NSString).size(withAttributes: indexAttrs)
            let wordSize = (word as NSString).size(withAttributes: wordAttrs)
            let itemWidth = indexSize.width + 3 + wordSize.width

            let itemRect = NSRect(x: x - 3, y: 0, width: itemWidth + itemSpacing, height: bounds.height)
            itemRects.append(itemRect)

            // 悬停高亮背景
            if i == hoveredIndex {
                let highlightPath = NSBezierPath(roundedRect: itemRect.insetBy(dx: 1, dy: 2), xRadius: 4, yRadius: 4)
                NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).setFill()
                highlightPath.fill()
            }

            (indexStr as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: indexAttrs)
            x += indexSize.width + 3
            (word as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: wordAttrs)
            x += wordSize.width + itemSpacing
        }
    }

    // 鼠标事件
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newIndex = itemRects.firstIndex(where: { $0.contains(point) }) ?? -1
        if newIndex != hoveredIndex {
            hoveredIndex = newIndex
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = -1
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = itemRects.firstIndex(where: { $0.contains(point) }) {
            onClicked?(index)
        }
    }
}
```

### Sources/WordDictionary.swift — 词库引擎

```swift
import Foundation

class WordDictionary {
    static let shared = WordDictionary()

    /// 按词频降序排列的词条
    private var entries: [(word: String, freq: Int)] = []
    /// 用户选词频率（持久化）
    private var userFreq: [String: Int] = [:]
    private let userDefaultsKey = "SmartEnglish_UserFreq"

    private init() {
        loadBuiltIn()
        loadUserFreq()
    }

    // MARK: - 加载词库

    private func loadBuiltIn() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt") else {
            NSLog("SmartEnglish ERROR: words.txt not found")
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
            // 过滤：只保留纯字母单词，长度 >= 2（除 a/i）
            guard word.allSatisfy({ $0.isLetter && $0.isASCII }) else { return nil }
            if word.count < 2 && word != "a" && word != "i" { return nil }
            return (word: word, freq: freq)
        }

        // 按频率降序
        entries.sort { $0.freq > $1.freq }
        NSLog("SmartEnglish: Loaded \(entries.count) words")
    }

    // MARK: - 查询

    /// 前缀匹配，返回最多 limit 个候选词（综合词频 + 用户频率排序）
    func query(prefix: String, limit: Int = 9) -> [String] {
        guard !prefix.isEmpty else { return [] }

        var matches: [(word: String, score: Double)] = []
        var exactMatch = false

        for entry in entries {
            guard entry.word.hasPrefix(prefix) else { continue }

            if entry.word == prefix {
                exactMatch = true
                continue // 完全匹配单独处理
            }

            let userBoost = Double(userFreq[entry.word] ?? 0) * 5000.0
            let score = Double(entry.freq) + userBoost
            matches.append((entry.word, score))

            // 性能：收集足够多候选后提前退出
            if matches.count >= limit * 5 { break }
        }

        // 按综合评分排序
        matches.sort { $0.score > $1.score }
        var result = Array(matches.prefix(limit).map { $0.word })

        // 完全匹配的词放第一位
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
}
```

---

## 词库准备脚本

### scripts/prepare_wordlist.py

```python
#!/usr/bin/env python3
"""
下载 Peter Norvig 的词频表，清洗后生成 words.txt
来源：https://norvig.com/ngrams/count_1w.txt
格式：word\tfrequency（Tab 分隔，按频率降序）
"""

import urllib.request
import re
import os

URL = "https://norvig.com/ngrams/count_1w.txt"
OUTPUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources", "words.txt")
MAX_WORDS = 50000

def is_valid_word(word: str) -> bool:
    """只保留纯英文字母单词"""
    if not word.isalpha():
        return False
    if len(word) < 2 and word.lower() not in ('a', 'i'):
        return False
    if len(word) > 30:
        return False
    return True

def main():
    print(f"Downloading word frequency data from {URL}...")
    response = urllib.request.urlopen(URL)
    content = response.read().decode('utf-8')

    print("Processing...")
    lines = content.strip().split('\n')
    words = []

    for line in lines:
        parts = line.split('\t')
        if len(parts) != 2:
            continue
        word, freq = parts[0].strip(), parts[1].strip()
        if not freq.isdigit():
            continue
        if is_valid_word(word):
            words.append((word.lower(), int(freq)))

    # 按频率降序排列
    words.sort(key=lambda x: x[1], reverse=True)

    # 去重（保留高频的）
    seen = set()
    unique_words = []
    for w, f in words:
        if w not in seen:
            seen.add(w)
            unique_words.append((w, f))

    # 取 Top N
    unique_words = unique_words[:MAX_WORDS]

    # 写入文件
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        for word, freq in unique_words:
            f.write(f"{word}\t{freq}\n")

    print(f"Done! Wrote {len(unique_words)} words to {OUTPUT}")
    print(f"Top 10: {[w for w, _ in unique_words[:10]]}")

if __name__ == "__main__":
    main()
```

---

## 构建和安装脚本

### Makefile

```makefile
.PHONY: generate build install dev clean uninstall log

PROJECT = SmartEnglish
SCHEME = SmartEnglish
CONFIG = Release
INPUT_METHODS_DIR = $(HOME)/Library/Input\ Methods
BUILD_DIR = $(shell xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$3}')

# 生成 Xcode 项目（首次或 project.yml 变更后执行）
generate:
	xcodegen generate
	@echo "✅ Xcode project generated"

# 准备词库
wordlist:
	python3 scripts/prepare_wordlist.py
	@echo "✅ Wordlist ready"

# 构建
build:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) build
	@echo "✅ Build succeeded"

# 安装到输入法目录
install:
	@echo "Installing SmartEnglish..."
	@killall $(PROJECT) 2>/dev/null || true
	@sleep 0.5
	@rm -rf ~/Library/Input\ Methods/$(PROJECT).app
	@cp -R "$$(xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$3}')/$(PROJECT).app" ~/Library/Input\ Methods/
	@echo "✅ Installed to ~/Library/Input Methods/"
	@echo "⚠️  首次安装需要去 系统设置 → 键盘 → 输入源 → 添加 SmartEnglish"
	@echo "⚠️  更新安装后需要切换到其他输入法再切回来，或注销重新登录"

# 开发一条龙：构建 + 安装
dev: build install
	@echo "🚀 Dev cycle complete"

# 清理构建产物
clean:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) clean 2>/dev/null || true
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(PROJECT)-*
	@echo "✅ Cleaned"

# 卸载
uninstall:
	killall $(PROJECT) 2>/dev/null || true
	rm -rf ~/Library/Input\ Methods/$(PROJECT).app
	@echo "✅ Uninstalled"

# 查看日志
log:
	log stream --predicate 'process == "SmartEnglish"' --level debug
```

### scripts/dev.sh（一键开发脚本）

```bash
#!/bin/bash
set -e

echo "🔨 Building SmartEnglish..."
xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release build 2>&1 | tail -5

echo "📦 Installing..."
killall SmartEnglish 2>/dev/null || true
sleep 0.5
rm -rf ~/Library/Input\ Methods/SmartEnglish.app

# 找到构建产物目录
BUILD_DIR=$(xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
cp -R "${BUILD_DIR}/SmartEnglish.app" ~/Library/Input\ Methods/

echo "✅ Done! SmartEnglish installed to ~/Library/Input Methods/"
echo ""
echo "📋 如果是首次安装："
echo "   1. 打开 系统设置 → 键盘 → 输入源"
echo "   2. 点击 + 添加输入源"
echo "   3. 在 English 分类下找到 SmartEnglish"
echo "   4. 在菜单栏切换到 SmartEnglish 即可使用"
echo ""
echo "📋 如果是更新安装："
echo "   切换到其他输入法再切回 SmartEnglish，或注销重新登录"
```

---

## 图标生成

菜单栏图标 main.tiff 需要是 16x16 + 32x32 的多分辨率 TIFF。可以用以下命令从一个 PNG 生成：

```bash
# 先创建一个简单的 16x16 PNG（字母 "SE"）
# 用 sips 或 ImageMagick 生成
# 最简单的方案：用 Python + Pillow 生成

python3 -c "
from PIL import Image, ImageDraw, ImageFont
import os

for size in [16, 32]:
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # 简单画一个蓝色圆角矩形 + 白色 E
    draw.rounded_rectangle([0, 0, size-1, size-1], radius=size//4, fill=(59, 130, 246))
    fontsize = size * 3 // 4
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', fontsize)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0,0), 'E', font=font)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    draw.text(((size-tw)//2 - bbox[0], (size-th)//2 - bbox[1]), 'E', fill='white', font=font)
    img.save(f'/tmp/icon_{size}.png')

# 合并为 TIFF
os.system('tiffutil -catnosizecheck /tmp/icon_16.png /tmp/icon_32.png -out Resources/main.tiff')
"
```

如果没装 Pillow，更简单的方案：用 macOS 自带工具创建一个纯色图标

```bash
# 用 sips 创建最简单的图标（一个蓝色方块）
python3 -c "
import struct, zlib, os

def create_png(size, path):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    raw = b''
    for y in range(size):
        raw += b'\x00'  # filter none
        for x in range(size):
            # 蓝色圆角矩形简化为纯蓝色方块
            raw += struct.pack('BBBB', 59, 130, 246, 255)

    ihdr = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(raw)))
        f.write(chunk(b'IEND', b''))

os.makedirs('Resources', exist_ok=True)
create_png(16, '/tmp/icon_16.png')
create_png(32, '/tmp/icon_32.png')
os.system('tiffutil -catnosizecheck /tmp/icon_16.png /tmp/icon_32.png -out Resources/main.tiff')
print('✅ Icon created: Resources/main.tiff')
"
```

---

## 交互设计规范

### 按键行为映射

| 按键 | 无输入状态 | 有输入状态（composing） |
|------|-----------|----------------------|
| a-z | 进入 composing，显示候选 | 追加字母，更新候选 |
| Backspace | 透传 | 删除末尾字母；全删完则退出 |
| Space | 透传 | 选第 1 个候选词；无候选则上屏原文 |
| Enter | 透传 | 上屏原始输入（不选候选） |
| Tab | 透传 | 选第 1 个候选词 |
| 1-9 | 透传 | 选对应序号候选词 |
| Escape | 透传 | 清空输入，关闭候选窗口 |
| Cmd/Ctrl/Opt+* | 透传 | 先上屏，再透传 |
| 标点/符号 | 透传 | 先上屏，再透传 |

### 候选窗口

- **触发：** 输入 ≥ 1 个字母 且 词库有匹配
- **位置：** 光标正下方，空间不够则上方
- **样式：** 横排 `1.word  2.word  3.word`，圆角半透明背景，系统字体
- **消失：** 选词 / ESC / 切应用 / 输入清空
- **最多：** 9 个候选词
- **鼠标：** 悬停高亮，点击选词

---

## 给 Claude Code 的开发顺序指令

请严格按以下顺序执行：

### Phase 1: 项目骨架
1. 创建项目目录结构（Sources/, Resources/, scripts/）
2. 创建 `project.yml`（XcodeGen 配置）
3. 创建 `Info.plist` 和 `SmartEnglish.entitlements`
4. 创建图标 `Resources/main.tiff`
5. 检查 `xcodegen` 是否已安装，没有则执行 `brew install xcodegen`
6. 运行 `xcodegen generate` 生成 .xcodeproj

### Phase 2: 词库
7. 创建 `scripts/prepare_wordlist.py`
8. 运行脚本生成 `Resources/words.txt`（注意：需要网络访问 norvig.com）
9. 如果网络不通，准备一个内嵌的 fallback 小词库（5000 词）

### Phase 3: 核心代码
10. 创建 `Sources/main.swift`
11. 创建 `Sources/AppDelegate.swift`
12. 创建 `Sources/WordDictionary.swift`
13. 创建 `Sources/CandidateView.swift`
14. 创建 `Sources/CandidateWindow.swift`
15. 创建 `Sources/SmartEnglishInputController.swift`

### Phase 4: 构建与测试
16. 创建 `Makefile` 和 `scripts/dev.sh`
17. 运行 `make generate`（生成 Xcode 项目）
18. 运行 `make build`（首次构建，修复编译错误）
19. 运行 `make install`（安装到输入法目录）
20. 创建 `README.md`（安装和使用说明）

### 重要注意事项
- Bundle ID **必须**包含 `.inputmethod.`
- InputMethodConnectionName **必须**是 `$(PRODUCT_BUNDLE_IDENTIFIER)_Connection`
- **不要用 IMKCandidates**，自己用 NSPanel 实现候选窗口
- `@objc(SmartEnglishInputController)` 注解不能省
- 所有 IMKInputController 方法签名必须与 IMKit 框架精确匹配
- 输入法调试很痛苦——每次改完要 kill 进程，有时要注销登录
- 如果编译报错，仔细检查 Info.plist 中的变量引用（`$(PRODUCT_MODULE_NAME)` 等）
