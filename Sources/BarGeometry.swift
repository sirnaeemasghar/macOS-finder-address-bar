import Foundation
import CoreGraphics

// All input rectangles use global, top-left screen coordinates.
enum BarGeometry {
    static func slot(navigation: CGRect, controls: [CGRect], toolbar: CGRect) -> CGRect? {
        let left = navigation.maxX + 8
        let next = controls.filter { $0.width > 0 && $0.minX >= left && abs($0.midY - navigation.midY) < 20 }.map(\.minX).min() ?? toolbar.maxX - 8
        let width = next - left - 8
        guard width >= 70 else { return nil }
        let height = max(36, min(40, navigation.height + 4))
        return CGRect(x: left, y: navigation.midY - height / 2, width: width, height: height)
    }
    static func fallback(window: CGRect, sidebar: CGFloat) -> CGRect? {
        let left = window.minX + max(0, sidebar) + 92
        let width = window.maxX - left - 280
        guard width >= 80 else { return nil }
        return CGRect(x: left, y: window.minY + 10, width: min(350, width), height: 32)
    }
}
