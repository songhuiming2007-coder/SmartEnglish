import Cocoa

class CandidateWindow {
    static let shared = CandidateWindow()

    private let panel: NSPanel
    private let candidateView: CandidateView
    private let visualEffect: NSVisualEffectView
    var onCandidateSelected: ((Int) -> Void)?

    /// 当前选中候选词索引（供方向键控制）
    var selectedIndex: Int {
        get { candidateView.selectedIndex }
        set { candidateView.selectedIndex = newValue }
    }

    private init() {
        candidateView = CandidateView()

        visualEffect = NSVisualEffectView()
        visualEffect.material = .menu
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true

        // 初始高度 = pillHeight(26) * 1.36 ≈ 35.4，实际由 idealSize() 覆盖
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 36),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        // .screenSaver 高于沙盒应用保存面板（openAndSavePanelService 渲染，层级高于 .popUpMenu）
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        panel.contentView = visualEffect
        visualEffect.addSubview(candidateView)

        candidateView.onClicked = { [weak self] index in
            self?.onCandidateSelected?(index)
        }
    }

    func show(candidates: [String], cursorRect: NSRect) {
        candidateView.update(candidates: candidates)

        let size = candidateView.idealSize()
        panel.setContentSize(size)
        visualEffect.frame = NSRect(origin: .zero, size: size)
        candidateView.frame = NSRect(origin: .zero, size: size)

        visualEffect.layer?.cornerRadius = size.height / 2
        visualEffect.layer?.masksToBounds = true

        var origin = cursorRect.origin
        origin.y -= size.height + 4

        // 用光标所在的屏幕做边缘裁剪（NSScreen.main 在多显示器下可能是错的屏）
        let cursorScreen = NSScreen.screens.first { $0.frame.contains(cursorRect.origin) } ?? NSScreen.main
        if let screen = cursorScreen {
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
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
