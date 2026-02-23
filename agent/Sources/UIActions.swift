import XCTest

/// Wraps XCUITest gesture APIs. All XCUITest calls must execute on the main thread.
class UIActions {

    /// SpringBoard app used as coordinate space for absolute screen coordinates.
    private var springboard: XCUIApplication {
        return XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    // MARK: - Gestures

    func tap(x: Double, y: Double) -> Bool {
        return onMain {
            let coord = self.coordinate(x: x, y: y)
            coord.tap()
            return true
        }
    }

    func doubleTap(x: Double, y: Double) -> Bool {
        return onMain {
            let coord = self.coordinate(x: x, y: y)
            coord.doubleTap()
            return true
        }
    }

    func longPress(x: Double, y: Double, duration: Double) -> Bool {
        return onMain {
            let coord = self.coordinate(x: x, y: y)
            coord.press(forDuration: duration)
            return true
        }
    }

    func swipe(startX: Double, startY: Double, endX: Double, endY: Double, duration: Double) -> Bool {
        return onMain {
            let start = self.coordinate(x: startX, y: startY)
            let end = self.coordinate(x: endX, y: endY)
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0)
            return true
        }
    }

    func typeText(_ text: String, bundleId: String?) -> Bool {
        return onMain {
            let app: XCUIApplication
            if let bundleId = bundleId {
                app = XCUIApplication(bundleIdentifier: bundleId)
            } else {
                // Target Springboard to find any focused text field across all apps
                app = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            }
            app.typeText(text)
            return true
        }
    }

    func pressButton(_ button: String) -> Bool {
        return onMain {
            switch button.lowercased() {
            case "home":
                XCUIDevice.shared.press(.home)
                return true
            default:
                NSLog("[UIActions] Unknown or unsupported button: \(button)")
                return false
            }
        }
    }

    func launchApp(bundleId: String) -> Bool {
        return onMain {
            let app = XCUIApplication(bundleIdentifier: bundleId)
            app.launch()
            return true
        }
    }

    // MARK: - Helpers

    private func coordinate(x: Double, y: Double) -> XCUICoordinate {
        let normalized = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        return normalized.withOffset(CGVector(dx: x, dy: y))
    }

    /// Dispatch to main thread synchronously. XCUITest APIs require main thread.
    private func onMain<T>(_ block: @escaping () -> T) -> T {
        if Thread.isMainThread {
            return block()
        }
        var result: T!
        DispatchQueue.main.sync {
            result = block()
        }
        return result
    }
}
