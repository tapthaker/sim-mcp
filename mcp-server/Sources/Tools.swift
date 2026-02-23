import Foundation

/// Registry of all MCP tools with JSON Schema definitions and dispatch logic.
struct ToolRegistry {

    func allToolSchemas() -> [[String: Any]] {
        return [
            // Device Management
            tool(
                name: "list_simulators",
                description: "List all available iOS simulators",
                properties: [:],
                required: []
            ),
            tool(
                name: "boot_simulator",
                description: "Boot an iOS simulator by UDID",
                properties: ["udid": string("Simulator UDID")],
                required: ["udid"]
            ),
            tool(
                name: "shutdown_simulator",
                description: "Shut down an iOS simulator by UDID",
                properties: ["udid": string("Simulator UDID")],
                required: ["udid"]
            ),

            // App Management
            tool(
                name: "install_app",
                description: "Install an app on a simulator",
                properties: [
                    "udid": string("Simulator UDID"),
                    "appPath": string("Path to .app bundle")
                ],
                required: ["udid", "appPath"]
            ),
            tool(
                name: "launch_app",
                description: "Launch an app on a simulator",
                properties: [
                    "udid": string("Simulator UDID"),
                    "bundleId": string("App bundle identifier")
                ],
                required: ["udid", "bundleId"]
            ),
            tool(
                name: "terminate_app",
                description: "Terminate a running app on a simulator",
                properties: [
                    "udid": string("Simulator UDID"),
                    "bundleId": string("App bundle identifier")
                ],
                required: ["udid", "bundleId"]
            ),
            tool(
                name: "list_apps",
                description: "List installed apps on a simulator",
                properties: ["udid": string("Simulator UDID")],
                required: ["udid"]
            ),

            // UI Automation
            tool(
                name: "tap",
                description: "Tap at screen coordinates",
                properties: [
                    "udid": string("Simulator UDID"),
                    "x": number("X coordinate"),
                    "y": number("Y coordinate")
                ],
                required: ["udid", "x", "y"]
            ),
            tool(
                name: "double_tap",
                description: "Double tap at screen coordinates",
                properties: [
                    "udid": string("Simulator UDID"),
                    "x": number("X coordinate"),
                    "y": number("Y coordinate")
                ],
                required: ["udid", "x", "y"]
            ),
            tool(
                name: "long_press",
                description: "Long press at screen coordinates",
                properties: [
                    "udid": string("Simulator UDID"),
                    "x": number("X coordinate"),
                    "y": number("Y coordinate"),
                    "duration": number("Press duration in seconds (default 1.0)")
                ],
                required: ["udid", "x", "y"]
            ),
            tool(
                name: "swipe",
                description: "Swipe from one point to another",
                properties: [
                    "udid": string("Simulator UDID"),
                    "startX": number("Start X coordinate"),
                    "startY": number("Start Y coordinate"),
                    "endX": number("End X coordinate"),
                    "endY": number("End Y coordinate"),
                    "duration": number("Swipe duration in seconds (default 0.5)")
                ],
                required: ["udid", "startX", "startY", "endX", "endY"]
            ),
            tool(
                name: "type_text",
                description: "Type text into the focused element. Pass bundleId of the foreground app for reliable text input.",
                properties: [
                    "udid": string("Simulator UDID"),
                    "text": string("Text to type"),
                    "bundleId": string("Bundle ID of the foreground app (recommended for reliable input)")
                ],
                required: ["udid", "text"]
            ),
            tool(
                name: "press_button",
                description: "Press a hardware button (home)",
                properties: [
                    "udid": string("Simulator UDID"),
                    "button": string("Button name: home")
                ],
                required: ["udid", "button"]
            ),
            tool(
                name: "get_ui_tree",
                description: "Get the accessibility tree of the current UI",
                properties: [
                    "udid": string("Simulator UDID"),
                    "bundleId": string("App bundle identifier (optional, defaults to SpringBoard)")
                ],
                required: ["udid"]
            ),

            // Screen & System
            tool(
                name: "screenshot",
                description: "Take a screenshot of the simulator and return as base64 PNG",
                properties: ["udid": string("Simulator UDID")],
                required: ["udid"]
            ),
            tool(
                name: "open_url",
                description: "Open a URL on the simulator",
                properties: [
                    "udid": string("Simulator UDID"),
                    "url": string("URL to open")
                ],
                required: ["udid", "url"]
            ),
            tool(
                name: "set_location",
                description: "Set the simulated GPS location",
                properties: [
                    "udid": string("Simulator UDID"),
                    "lat": number("Latitude"),
                    "lon": number("Longitude")
                ],
                required: ["udid", "lat", "lon"]
            ),
            tool(
                name: "send_push_notification",
                description: "Send a push notification to an app on the simulator",
                properties: [
                    "udid": string("Simulator UDID"),
                    "bundleId": string("App bundle identifier"),
                    "title": string("Notification title"),
                    "body": string("Notification body"),
                    "badge": ["type": "integer", "description": "Badge count (optional)"] as [String: Any]
                ],
                required: ["udid", "bundleId", "title", "body"]
            ),
        ]
    }

    /// Dispatch a tool call to the appropriate handler.
    func dispatch(
        name: String,
        arguments: [String: Any],
        simulatorManager: SimulatorManager,
        agentClient: AgentClient
    ) -> [String: Any] {
        switch name {
        // Device Management
        case "list_simulators":
            return simulatorManager.listSimulators()

        case "boot_simulator":
            guard let udid = arguments["udid"] as? String else {
                return missingParam("udid")
            }
            return simulatorManager.bootSimulator(udid: udid)

        case "shutdown_simulator":
            guard let udid = arguments["udid"] as? String else {
                return missingParam("udid")
            }
            return simulatorManager.shutdownSimulator(udid: udid)

        // App Management
        case "install_app":
            guard let udid = arguments["udid"] as? String,
                  let appPath = arguments["appPath"] as? String else {
                return missingParam("udid, appPath")
            }
            return simulatorManager.installApp(udid: udid, appPath: appPath)

        case "launch_app":
            guard let udid = arguments["udid"] as? String,
                  let bundleId = arguments["bundleId"] as? String else {
                return missingParam("udid, bundleId")
            }
            return simulatorManager.launchApp(udid: udid, bundleId: bundleId)

        case "terminate_app":
            guard let udid = arguments["udid"] as? String,
                  let bundleId = arguments["bundleId"] as? String else {
                return missingParam("udid, bundleId")
            }
            return simulatorManager.terminateApp(udid: udid, bundleId: bundleId)

        case "list_apps":
            guard let udid = arguments["udid"] as? String else {
                return missingParam("udid")
            }
            return simulatorManager.listApps(udid: udid)

        // UI Automation — routed through agent
        case "tap", "double_tap", "long_press", "swipe", "type_text", "press_button", "get_ui_tree", "launch_app_via_agent":
            guard let udid = arguments["udid"] as? String else {
                return missingParam("udid")
            }
            var body = arguments
            body.removeValue(forKey: "udid")
            let path = "/\(name)"
            return agentClient.sendRequest(udid: udid, path: path, body: body)

        // Screen & System
        case "screenshot":
            guard let udid = arguments["udid"] as? String else {
                return missingParam("udid")
            }
            return simulatorManager.screenshot(udid: udid)

        case "open_url":
            guard let udid = arguments["udid"] as? String,
                  let url = arguments["url"] as? String else {
                return missingParam("udid, url")
            }
            return simulatorManager.openURL(udid: udid, url: url)

        case "set_location":
            guard let udid = arguments["udid"] as? String,
                  let lat = arguments["lat"] as? Double,
                  let lon = arguments["lon"] as? Double else {
                return missingParam("udid, lat, lon")
            }
            return simulatorManager.setLocation(udid: udid, lat: lat, lon: lon)

        case "send_push_notification":
            guard let udid = arguments["udid"] as? String,
                  let bundleId = arguments["bundleId"] as? String,
                  let title = arguments["title"] as? String,
                  let body = arguments["body"] as? String else {
                return missingParam("udid, bundleId, title, body")
            }
            let badge = arguments["badge"] as? Int
            return simulatorManager.sendPushNotification(udid: udid, bundleId: bundleId, title: title, body: body, badge: badge)

        default:
            return ["content": [["type": "text", "text": "Unknown tool: \(name)"]], "isError": true]
        }
    }

    // MARK: - Schema helpers

    private func tool(name: String, description: String, properties: [String: [String: Any]], required: [String]) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        return [
            "name": name,
            "description": description,
            "inputSchema": schema
        ]
    }

    private func string(_ description: String) -> [String: Any] {
        return ["type": "string", "description": description]
    }

    private func number(_ description: String) -> [String: Any] {
        return ["type": "number", "description": description]
    }

    private func missingParam(_ param: String) -> [String: Any] {
        return ["content": [["type": "text", "text": "Missing required parameter: \(param)"]], "isError": true]
    }
}
