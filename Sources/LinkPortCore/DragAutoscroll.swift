import CoreGraphics

public enum DragAutoscroll {
    public static func direction(at point: CGPoint, in size: CGSize) -> Int {
        guard point.x.isFinite, point.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              (0...size.width).contains(point.x), (0...size.height).contains(point.y) else { return 0 }
        let edge = min(48, size.height / 3)
        if point.y < edge { return -1 }
        if point.y > size.height - edge { return 1 }
        return 0
    }
}
