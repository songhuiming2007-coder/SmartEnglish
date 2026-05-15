import Cocoa

class CandidateView: NSView {
    private var candidates: [String] = []
    private var itemRects: [NSRect] = []
    private var selectedIndex: Int = 0
    var onClicked: ((Int) -> Void)?

    private let font = NSFont.systemFont(ofSize: 14)
    private let indexFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let hPadding: CGFloat = 12
    private let itemSpacing: CGFloat = 20
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
        self.selectedIndex = 0
        needsDisplay = true
    }

    func idealSize() -> NSSize {
        var totalWidth: CGFloat = hPadding
        for (i, word) in candidates.enumerated() {
            let indexStr = "\(i + 1)"
            let indexSize = (indexStr as NSString).size(withAttributes: [.font: indexFont])
            let wordSize = (word as NSString).size(withAttributes: [.font: font])
            totalWidth += indexSize.width + 4 + wordSize.width + itemSpacing
        }
        // Arrow space
        totalWidth += 16 + hPadding
        return NSSize(width: max(totalWidth, 80), height: 32)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Background
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor.windowBackgroundColor.setFill()
        bgPath.fill()

        var x: CGFloat = hPadding
        let y: CGFloat = vPadding
        itemRects = []

        for (i, word) in candidates.enumerated() {
            let indexStr = "\(i + 1)"
            let indexAttrs: [NSAttributedString.Key: Any] = [
                .font: indexFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]

            let isHighlighted = (i == selectedIndex)
            let wordAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isHighlighted ? NSColor.white : NSColor.labelColor
            ]

            let indexSize = (indexStr as NSString).size(withAttributes: indexAttrs)
            let wordSize = (word as NSString).size(withAttributes: wordAttrs)
            let itemWidth = indexSize.width + 4 + wordSize.width

            let itemRect = NSRect(x: x - 3, y: 0, width: itemWidth + itemSpacing, height: bounds.height)
            itemRects.append(itemRect)

            if isHighlighted {
                let highlightRect = NSRect(x: x - 4, y: 1, width: itemWidth + 4, height: bounds.height - 2)
                let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 6, yRadius: 6)
                NSColor.selectedContentBackgroundColor.setFill()
                highlightPath.fill()
            }

            (indexStr as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: indexAttrs)
            x += indexSize.width + 4
            (word as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: wordAttrs)
            x += wordSize.width + itemSpacing
        }

        // Arrow "∨"
        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let arrowStr = "∨"
        let arrowSize = (arrowStr as NSString).size(withAttributes: arrowAttrs)
        (arrowStr as NSString).draw(at: NSPoint(x: bounds.width - hPadding - arrowSize.width, y: y), withAttributes: arrowAttrs)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newIndex = itemRects.firstIndex(where: { $0.contains(point) }) ?? selectedIndex
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Keep selection on exit
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = itemRects.firstIndex(where: { $0.contains(point) }) {
            onClicked?(index)
        }
    }
}
