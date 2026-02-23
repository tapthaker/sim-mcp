import Foundation

/// JSON-RPC 2.0 MCP server that reads from stdin and writes to stdout.
class MCPServer {
    private let simulatorManager = SimulatorManager()
    private let agentClient = AgentClient()
    private let toolRegistry = ToolRegistry()

    func run() {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("Failed to parse JSON: \(line)")
                continue
            }

            let id = json["id"]
            let method = json["method"] as? String

            guard let method = method else {
                // Notifications without method — ignore
                continue
            }

            switch method {
            case "initialize":
                handleInitialize(id: id)

            case "notifications/initialized":
                // Client acknowledges initialization — no response needed
                continue

            case "ping":
                sendResult(id: id, result: [:])

            case "tools/list":
                handleToolsList(id: id)

            case "tools/call":
                handleToolsCall(id: id, params: json["params"] as? [String: Any] ?? [:])

            default:
                sendError(id: id, code: -32601, message: "Method not found: \(method)")
            }
        }

        log("stdin closed, shutting down")
    }

    // MARK: - Handlers

    private func handleInitialize(id: Any?) {
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [
                    "listChanged": false
                ]
            ],
            "serverInfo": [
                "name": "sim-mcp",
                "version": "0.1.0"
            ]
        ]
        sendResult(id: id, result: result)
    }

    private func handleToolsList(id: Any?) {
        sendResult(id: id, result: ["tools": toolRegistry.allToolSchemas()])
    }

    private func handleToolsCall(id: Any?, params: [String: Any]) {
        guard let name = params["name"] as? String else {
            sendError(id: id, code: -32602, message: "Missing tool name")
            return
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]

        let response = toolRegistry.dispatch(
            name: name,
            arguments: arguments,
            simulatorManager: simulatorManager,
            agentClient: agentClient
        )

        sendResult(id: id, result: response)
    }

    // MARK: - JSON-RPC response helpers

    private func sendResult(id: Any?, result: [String: Any]) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            response["id"] = id
        }
        writeJSON(response)
    }

    private func sendError(id: Any?, code: Int, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id = id {
            response["id"] = id
        }
        writeJSON(response)
    }

    private func writeJSON(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            log("Failed to serialize JSON response")
            return
        }
        print(str)
    }
}
