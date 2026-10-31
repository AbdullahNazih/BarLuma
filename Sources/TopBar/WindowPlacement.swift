import Foundation
import CoreGraphics

enum WindowPlacement {
    /// Uses AppKit screen coordinates, including displays left of or below the primary display.
    static func constrained(_ frame: CGRect, to visibleFrame: CGRect, margin: CGFloat = 12) -> CGRect {
        let safe = visibleFrame.insetBy(dx: min(margin, visibleFrame.width / 4),
                                       dy: min(margin, visibleFrame.height / 4))
        let width = min(frame.width, safe.width)
        let height = min(frame.height, safe.height)
        return CGRect(x: min(max(frame.minX, safe.minX), safe.maxX - width),
                      y: min(max(frame.minY, safe.minY), safe.maxY - height), width: width, height: height)
    }

    static func dashboard(size: CGSize, below anchor: CGRect, visibleFrame: CGRect) -> CGRect {
        constrained(CGRect(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 10,
                           width: size.width, height: size.height), to: visibleFrame)
    }
}
