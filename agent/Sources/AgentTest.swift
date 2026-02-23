import XCTest

class AgentTest: XCTestCase {

    private var server: HTTPServer!
    private var uiActions: UIActions!
    private var accessibilityTree: AccessibilityTree!

    func testRunAgent() {
        server = HTTPServer()
        uiActions = UIActions()
        accessibilityTree = AccessibilityTree()

        // Register routes
        server.addRoute("/health") { _ in
            return (200, ["status": "ok", "port": Int(self.server.port)])
        }

        server.addRoute("/tap") { body in
            guard let x = body["x"] as? Double,
                  let y = body["y"] as? Double else {
                return (400, ["error": "Missing x or y"])
            }
            let result = self.uiActions.tap(x: x, y: y)
            return result ? (200, ["success": true]) : (500, ["error": "Tap failed"])
        }

        server.addRoute("/double_tap") { body in
            guard let x = body["x"] as? Double,
                  let y = body["y"] as? Double else {
                return (400, ["error": "Missing x or y"])
            }
            let result = self.uiActions.doubleTap(x: x, y: y)
            return result ? (200, ["success": true]) : (500, ["error": "Double tap failed"])
        }

        server.addRoute("/long_press") { body in
            guard let x = body["x"] as? Double,
                  let y = body["y"] as? Double else {
                return (400, ["error": "Missing x or y"])
            }
            let duration = body["duration"] as? Double ?? 1.0
            let result = self.uiActions.longPress(x: x, y: y, duration: duration)
            return result ? (200, ["success": true]) : (500, ["error": "Long press failed"])
        }

        server.addRoute("/swipe") { body in
            guard let startX = body["startX"] as? Double,
                  let startY = body["startY"] as? Double,
                  let endX = body["endX"] as? Double,
                  let endY = body["endY"] as? Double else {
                return (400, ["error": "Missing startX, startY, endX, or endY"])
            }
            let duration = body["duration"] as? Double ?? 0.5
            let result = self.uiActions.swipe(startX: startX, startY: startY, endX: endX, endY: endY, duration: duration)
            return result ? (200, ["success": true]) : (500, ["error": "Swipe failed"])
        }

        server.addRoute("/type_text") { body in
            guard let text = body["text"] as? String else {
                return (400, ["error": "Missing text"])
            }
            let bundleId = body["bundleId"] as? String
            let result = self.uiActions.typeText(text, bundleId: bundleId)
            return result ? (200, ["success": true]) : (500, ["error": "Type text failed"])
        }

        server.addRoute("/press_button") { body in
            guard let button = body["button"] as? String else {
                return (400, ["error": "Missing button"])
            }
            let result = self.uiActions.pressButton(button)
            return result ? (200, ["success": true]) : (500, ["error": "Press button failed"])
        }

        server.addRoute("/get_ui_tree") { body in
            let bundleId = body["bundleId"] as? String
            let tree = self.accessibilityTree.getTree(bundleId: bundleId)
            return (200, tree)
        }

        server.addRoute("/launch_app") { body in
            guard let bundleId = body["bundleId"] as? String else {
                return (400, ["error": "Missing bundleId"])
            }
            let result = self.uiActions.launchApp(bundleId: bundleId)
            return result ? (200, ["success": true]) : (500, ["error": "Launch app failed"])
        }

        // Start server
        do {
            try server.start()
            NSLog("[Agent] Server started on port \(server.port)")
        } catch {
            XCTFail("Failed to start HTTP server: \(error)")
            return
        }

        // Block indefinitely — the test acts as a long-running agent process.
        // The MCP server will kill the xcodebuild process when it's done.
        let expectation = XCTestExpectation(description: "Agent running")
        expectation.isInverted = true
        wait(for: [expectation], timeout: .infinity)
    }
}
