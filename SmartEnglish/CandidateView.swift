import Cocoa

class CandidateView: NSView {
    private var candidates: [String] = []
    private var itemRects: [NSRect] = []
    private var hoveredIndex: Int = -1
    var onClicked: ((Int) -> Void)?

    private let font = NSFont.systemFont(ofSize: 14)
    private let indexFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let hPadding: CGFloat = 10
    private let itemSpacing: CGFloat = 14
    private let vPadding: CGFloat = 5

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
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
        bgPath.fill()
        NSColor.separatorColor.setStroke()
        bgPath.lineWidth = 0.5
        bgPath.stroke()

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
