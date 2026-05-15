import Cocoa

class CandidateWindow {
    static let shared = CandidateWindow()

    private let panel: NSPanel
    private let candidateView: CandidateView
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
        panel.isMovableByWindowBackground = false

        candidateView.onClicked = { [weak self] index in
            self?.onCandidateSelected?(index)
        }
    }

    func show(candidates: [String], cursorRect: NSRect) {
        candidateView.update(candidates: candidates)

        let size = candidateView.idealSize()
        panel.setContentSize(size)

        var origin = cursorRect.origin
        origin.y -= size.height + 4

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            if origin.x + size.width > frame.maxX {
                origin.x = frame.maxX - size.width
            }
            if origin.x < frame.minX {
                origin.x = frame.minX
            }
            if origin.y < frame.minY {
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
