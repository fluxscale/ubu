import CoreGraphics
import Foundation

/// Moves the Dock the way a person does: by pushing the pointer against the Dock
/// edge of the target display. No Dock restart and no private API.
enum DockMover {
    /// A short approach toward the Dock edge, ending one point inside it.
    static func pushPath(on frame: CGRect, dockPosition: DockPosition, steps: Int = 8) -> [CGPoint] {
        let approach: CGFloat = 50
        let start: CGPoint
        let edge: CGPoint
        switch dockPosition {
        case .bottom:
            start = CGPoint(x: frame.midX, y: frame.maxY - approach)
            edge = CGPoint(x: frame.midX, y: frame.maxY - 1)
        case .left:
            start = CGPoint(x: frame.minX + approach, y: frame.midY)
            edge = CGPoint(x: frame.minX + 1, y: frame.midY)
        case .right:
            start = CGPoint(x: frame.maxX - approach, y: frame.midY)
            edge = CGPoint(x: frame.maxX - 1, y: frame.midY)
        }
        return (0..<steps).map { i in
            let t = CGFloat(i) / CGFloat(steps - 1)
            return CGPoint(x: start.x + (edge.x - start.x) * t, y: start.y + (edge.y - start.y) * t)
        }
    }

    /// Pointer delta that reads as pressure into the Dock edge.
    static func pressure(for dockPosition: DockPosition) -> (dx: Int64, dy: Int64) {
        switch dockPosition {
        case .bottom: return (0, 5)
        case .left: return (-5, 0)
        case .right: return (5, 0)
        }
    }

    /// Takes about 0.4s, so it runs off the main thread to keep the event tap responsive.
    /// Posting events needs the Accessibility permission ubu already holds.
    static func push(to frame: CGRect, dockPosition: DockPosition) {
        DispatchQueue.global(qos: .userInitiated).async {
            let source = CGEventSource(stateID: .hidSystemState)
            let original = CGEvent(source: nil)?.location
            let path = pushPath(on: frame, dockPosition: dockPosition)
            let (dx, dy) = pressure(for: dockPosition)

            // Approach, then hold at the edge: the Dock reacts to sustained pressure, not one event.
            for (index, point) in (path + Array(repeating: path[path.count - 1], count: 8)).enumerated() {
                let holding = index >= path.count
                CGWarpMouseCursorPosition(point)
                if let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                       mouseCursorPosition: point, mouseButton: .left) {
                    if holding {
                        event.setIntegerValueField(.mouseEventDeltaX, value: dx)
                        event.setIntegerValueField(.mouseEventDeltaY, value: dy)
                    }
                    event.post(tap: .cghidEventTap)
                }
                usleep(holding ? 25_000 : 15_000)
            }

            if let original {
                CGWarpMouseCursorPosition(original)
            }
        }
    }
}
