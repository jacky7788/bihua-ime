import AppKit

/// 候選窗內容繪製
final class CandidateCanvas: NSView {
    private var chars: [Character] = []
    private var labels: [String] = []
    private var selected = 0
    private var fontSize: CGFloat = 24
    private var cellWidth: CGFloat = 42
    private var cellHeight: CGFloat = 48
    private var hasPrev = false
    private var hasNext = false
    private var pageText = ""

    private let navWidth: CGFloat = 26
    private var infoWidth: CGFloat { (hasNext || !pageText.isEmpty) ? 34 : 6 }

    override var isFlipped: Bool { true }

    func setup(chars: [Character], labels: [String], selected: Int, fontSize: CGFloat,
               hasPrev: Bool, hasNext: Bool, pageText: String) {
        self.chars = chars
        self.labels = labels
        self.selected = selected
        self.fontSize = fontSize
        self.hasPrev = hasPrev
        self.hasNext = hasNext
        self.pageText = pageText
        self.cellWidth = max(30, fontSize + 18)
        self.cellHeight = max(36, fontSize + 22)
        needsDisplay = true
    }

    override var fittingSize: NSSize {
        let count = CGFloat(max(chars.count, 1))
        var width = count * cellWidth + 12 + infoWidth
        if hasPrev { width += navWidth }
        return NSSize(width: min(width, 1400), height: cellHeight + 8)
    }

    private var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private var dimColor: NSColor {
        isDark ? NSColor(calibratedWhite: 0.62, alpha: 1)
               : NSColor(calibratedWhite: 0.45, alpha: 1)
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: body, xRadius: 9, yRadius: 9)

        if isDark {
            NSColor(calibratedWhite: 0.14, alpha: 0.98).setFill()
            NSColor(calibratedWhite: 0.38, alpha: 1).setStroke()
        } else {
            NSColor(calibratedWhite: 0.995, alpha: 0.98).setFill()
            NSColor(calibratedWhite: 0.74, alpha: 1).setStroke()
        }
        path.fill()
        path.lineWidth = 1
        path.stroke()

        guard !chars.isEmpty else { return }

        let charFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let indexFont = NSFont.monospacedDigitSystemFont(ofSize: max(9, fontSize * 0.40),
                                                         weight: .medium)
        let navFont = NSFont.systemFont(ofSize: max(9, fontSize * 0.42), weight: .semibold)
        let pageFont = NSFont.monospacedDigitSystemFont(ofSize: max(8, fontSize * 0.34),
                                                        weight: .regular)
        let accent = NSColor.controlAccentColor
        var x = 6.0

        // 左邊：幾頁之前先有，等於原版 ◀
        if hasPrev {
            drawNav(x: x, symbol: "◀", key: keyForPrev(), font: navFont,
                    keyFont: navFont, color: dimColor)
            x += navWidth
        }

        for (i, ch) in chars.enumerated() {
            let cell = NSRect(x: x, y: 4, width: cellWidth - 2, height: cellHeight - 2)
            if i == selected {
                let hl = NSBezierPath(roundedRect: cell, xRadius: 6, yRadius: 6)
                accent.withAlphaComponent(0.88).setFill()
                hl.fill()
            }

            let textColor: NSColor = (i == selected)
                ? .white
                : (isDark ? NSColor(calibratedWhite: 0.95, alpha: 1)
                          : NSColor(calibratedWhite: 0.10, alpha: 1))

            let s = String(ch)
            let size = s.size(withAttributes: [.font: charFont])
            s.draw(at: NSPoint(x: cell.midX - size.width / 2,
                               y: cell.midY - size.height / 2 + 2),
                   withAttributes: [.font: charFont, .foregroundColor: textColor])

            let key = i < labels.count ? labels[i] : "\(i + 1)"
            NSAttributedString(string: key, attributes: [
                .font: indexFont,
                .foregroundColor: (i == selected)
                    ? NSColor(calibratedWhite: 1, alpha: 0.8)
                    : dimColor,
            ]).draw(at: NSPoint(x: cell.minX + 4, y: cell.minY + 1))

            x += cellWidth
        }

        // 右邊：頁碼 + 下一頁 ▶
        let infoRect = NSRect(x: x + 2, y: 4, width: infoWidth - 4, height: cellHeight - 6)
        if !pageText.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [.font: pageFont, .foregroundColor: dimColor]
            let sz = pageText.size(withAttributes: attrs)
            NSAttributedString(string: pageText, attributes: attrs)
                .draw(at: NSPoint(x: infoRect.midX - sz.width / 2, y: infoRect.minY + 1))
        }
        if hasNext {
            drawNav(x: infoRect.minX, symbol: "▶", key: keyForNext(), font: navFont,
                    keyFont: navFont, color: dimColor, yOffset: 10)
        }
    }

    private func drawNav(x: CGFloat, symbol: String, key: String,
                         font: NSFont, keyFont: NSFont, color: NSColor,
                         yOffset: CGFloat = 0) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let s = symbol.size(withAttributes: attrs)
        let cx = x + navWidth / 2
        symbol.draw(at: NSPoint(x: cx - s.width / 2, y: 12 + yOffset), withAttributes: attrs)
        if !key.isEmpty {
            let kattrs: [NSAttributedString.Key: Any] = [.font: keyFont, .foregroundColor: color]
            let ks = key.size(withAttributes: kattrs)
            key.draw(at: NSPoint(x: cx - ks.width / 2, y: 30 + yOffset), withAttributes: kattrs)
        }
    }

    func keyForPrev() -> String { prevLabel }
    func keyForNext() -> String { nextLabel }

    var prevLabel: String = "y"
    var nextLabel: String = "n"
}

/// 浮動候選窗
final class CandidatePanel: NSPanel {
    private let canvas = CandidateCanvas()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 120, height: 50),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary,
                              .ignoresCycle]
        contentView = canvas
    }

    func show(chars: [Character], labels: [String], selected: Int, at caret: NSRect,
              fontSize: CGFloat, hasPrev: Bool, hasNext: Bool, pageText: String,
              prevKey: String, nextKey: String) {
        canvas.prevLabel = prevKey
        canvas.nextLabel = nextKey
        canvas.setup(chars: chars, labels: labels, selected: selected, fontSize: fontSize,
                     hasPrev: hasPrev, hasNext: hasNext, pageText: pageText)

        let size = canvas.fittingSize
        var origin = NSPoint(x: caret.minX, y: caret.minY - size.height - 4)

        let anchor = NSPoint(x: caret.midX, y: caret.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            origin.x = min(origin.x, vf.maxX - size.width - 6)
            origin.x = max(origin.x, vf.minX + 6)
            if origin.y < vf.minY { origin.y = caret.maxY + 6 }
            if origin.y + size.height > vf.maxY {
                origin.y = max(vf.minY + 6, vf.maxY - size.height - 6)
            }
        }

        setFrame(NSRect(origin: origin, size: size), display: true)
        orderFrontRegardless()
    }

    func hidePanel() {
        orderOut(nil)
    }
}
