import Cocoa

class CandidateView: NSView {
    private var candidates: [String] = []
    private var itemRects: [NSRect] = []
    var selectedIndex: Int = 0 { didSet { needsDisplay = true } }
    var onClicked: ((Int) -> Void)?

    // === 唯一调节点 ===
    private let pillHeight: CGFloat = 24

    // === 派生几何（全部从 pillHeight 推导） ===
    private var windowVerticalPadding: CGFloat { pillHeight * 0.18 }
    private var windowHeight: CGFloat { pillHeight + windowVerticalPadding * 2 }
    private var windowHorizontalPadding: CGFloat { pillHeight * 0.35 }
    private var pillCornerRadius: CGFloat { pillHeight / 2 }
    private var pillLeftPadding: CGFloat { pillHeight * 0.38 }
    private var pillRightPadding: CGFloat { pillHeight * 0.50 }
    private var pillContentGap: CGFloat { pillHeight * 0.18 }
    private var itemGap: CGFloat { pillHeight * 0.55 }
    private var wordFont: NSFont { NSFont.systemFont(ofSize: pillHeight * 0.54) }
    private var indexFont: NSFont { NSFont.systemFont(ofSize: pillHeight * 0.42) }

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
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
        self.selectedIndex = 0
        needsDisplay = true
    }

    // MARK: - 横向布局算法

    private typealias LayoutItem = (pillRect: NSRect, indexX: CGFloat, wordX: CGFloat)

    private func computeLayout() -> [LayoutItem] {
        var items: [LayoutItem] = []
        var cursorX: CGFloat = windowHorizontalPadding

        for (i, word) in candidates.enumerated() {
            let indexStr = "\(i + 1)"
            let indexWidth = (indexStr as NSString).size(withAttributes: [.font: indexFont]).width
            let wordWidth = (word as NSString).size(withAttributes: [.font: wordFont]).width

            // pill 总宽度 = 左内边距 + 数字 + 间距 + 单词 + 右内边距
            let pillWidth = pillLeftPadding + indexWidth + pillContentGap + wordWidth + pillRightPadding

            let pillRect = NSRect(
                x: cursorX,
                y: windowVerticalPadding,
                width: pillWidth,
                height: pillHeight
            )

            let indexX = cursorX + pillLeftPadding
            let wordX = indexX + indexWidth + pillContentGap

            items.append((pillRect, indexX, wordX))

            cursorX = pillRect.maxX + itemGap
        }

        return items
    }

    func idealSize() -> NSSize {
        let layout = computeLayout()

        var totalWidth: CGFloat
        if let last = layout.last {
            totalWidth = last.pillRect.maxX + windowHorizontalPadding
        } else {
            totalWidth = windowHorizontalPadding * 2
        }

        return NSSize(width: max(totalWidth, 80), height: windowHeight)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        // 背景由 NSVisualEffectView 处理，这里只画内容
        let layout = computeLayout()
        itemRects = []

        for (i, (pillRect, indexX, wordX)) in layout.enumerated() {
            let isSelected = (i == selectedIndex)
            itemRects.append(pillRect)

            // 1. 画 pill（只有选中的画 pill 背景）
            if isSelected {
                let path = NSBezierPath(
                    roundedRect: pillRect,
                    xRadius: pillCornerRadius,
                    yRadius: pillCornerRadius
                )
                NSColor.controlAccentColor.setFill()
                path.fill()
            }

            // 2. 画数字（标准排版居中：baseline = 中心 - ascender/2）
            let indexStr = "\(i + 1)"
            let indexBaselineY = pillRect.midY - indexFont.ascender / 2
            let indexAttrs: [NSAttributedString.Key: Any] = [
                .font: indexFont,
                .foregroundColor: isSelected
                    ? NSColor.white.withAlphaComponent(0.85)
                    : NSColor.secondaryLabelColor
            ]
            (indexStr as NSString).draw(
                at: NSPoint(x: indexX, y: indexBaselineY),
                withAttributes: indexAttrs
            )

            // 3. 画单词（标准排版居中：baseline = 中心 - ascender/2）
            let word = candidates[i]
            let wordBaselineY = pillRect.midY - wordFont.ascender / 2
            let wordAttrs: [NSAttributedString.Key: Any] = [
                .font: wordFont,
                .foregroundColor: isSelected ? NSColor.white : NSColor.labelColor
            ]
            (word as NSString).draw(
                at: NSPoint(x: wordX, y: wordBaselineY),
                withAttributes: wordAttrs
            )
        }
    }

    // MARK: - 鼠标交互

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newIndex = itemRects.firstIndex(where: { $0.contains(point) }) ?? selectedIndex
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {}

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = itemRects.firstIndex(where: { $0.contains(point) }) {
            onClicked?(index)
        }
    }
}
