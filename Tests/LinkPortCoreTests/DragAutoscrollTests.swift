import CoreGraphics
import LinkPortCore
import Testing

@Test(arguments: [
    (point: CGPoint(x: 100, y: 0), expected: -1),
    (point: CGPoint(x: 100, y: 47), expected: -1),
    (point: CGPoint(x: 100, y: 48), expected: 0),
    (point: CGPoint(x: 100, y: 200), expected: 0),
    (point: CGPoint(x: 100, y: 353), expected: 1),
    (point: CGPoint(x: 100, y: 400), expected: 1),
    (point: CGPoint(x: -1, y: 20), expected: 0),
    (point: CGPoint(x: 201, y: 20), expected: 0),
    (point: CGPoint(x: 100, y: -1), expected: 0),
    (point: CGPoint(x: 100, y: 401), expected: 0),
    (point: CGPoint(x: CGFloat.nan, y: 20), expected: 0),
])
func dragAutoscrollRecognizesViewportEdges(_ scenario: (point: CGPoint, expected: Int)) {
    #expect(DragAutoscroll.direction(at: scenario.point, in: CGSize(width: 200, height: 400)) == scenario.expected)
}

@Test func dragAutoscrollHandlesSmallAndInvalidViewports() {
    #expect(DragAutoscroll.direction(at: CGPoint(x: 10, y: 29), in: CGSize(width: 100, height: 60)) == 0)
    #expect(DragAutoscroll.direction(at: CGPoint(x: 10, y: 0), in: .zero) == 0)
    #expect(DragAutoscroll.direction(at: CGPoint(x: 10, y: 0), in: CGSize(width: 100, height: CGFloat.infinity)) == 0)
}
