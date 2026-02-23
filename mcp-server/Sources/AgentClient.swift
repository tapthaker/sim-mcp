import Foundation

/// Manages XCTest agent lifecycle per simulator and routes HTTP requests to agents.
class AgentClient {

    /// Tracks running agent processes per simulator UDID.
    private var agents: [String: AgentInfo] = [:]
    private var nextPort: UInt16 = 8100

    struct AgentInfo {
        let udid: String
        let port: UInt16
        let process: Process
    }

    /// Ensure agent is running on the given simulator, starting it if needed.
    func ensureAgentRunning(udid: String) -> Result<UInt16, Error> {
        if let info = agents[udid] {
            if info.process.isRunning {
                return .success(info.port)
            }
            // Process died, clean up
            agents.removeValue(forKey: udid)
        }

        let port = nextPort
        nextPort += 1

        // Find the agent binaries relative to this binary
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let binaryDir = URL(fileURLWithPath: binaryPath).deletingLastPathComponent().path
        let installDir = (binaryDir as NSString).expandingTildeInPath

        let xctestrunPath = "\(installDir)/AgentTest.xctestrun"

        guard FileManager.default.fileExists(atPath: xctestrunPath) else {
            return .failure(AgentError.missingXctestrun(xctestrunPath))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "test-without-building",
            "-xctestrun", xctestrunPath,
            "-destination", "platform=iOS Simulator,id=\(udid)",
            "-only-testing:AgentTest/AgentTest/testRunAgent"
        ]

        // Set port via environment variable
        var env = ProcessInfo.processInfo.environment
        env["AGENT_PORT"] = "\(port)"
        // Also inject via xctestrun env — handled by the xctestrun plist
        process.environment = env

        // Redirect stdout/stderr to log files so they don't interfere with MCP stdio
        let logDir = NSTemporaryDirectory() + "sim-mcp-logs"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        let logFile = FileHandle(forWritingAtPath: "\(logDir)/agent-\(udid).log")
            ?? { () -> FileHandle in
                FileManager.default.createFile(atPath: "\(logDir)/agent-\(udid).log", contents: nil)
                return FileHandle(forWritingAtPath: "\(logDir)/agent-\(udid).log")!
            }()

        process.standardOutput = logFile
        process.standardError = logFile

        do {
            try process.run()
        } catch {
            return .failure(AgentError.launchFailed(error.localizedDescription))
        }

        agents[udid] = AgentInfo(udid: udid, port: port, process: process)

        // Wait for agent to become healthy
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if healthCheck(port: port) {
                log("Agent running on \(udid) at port \(port)")
                return .success(port)
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Timeout — kill process
        process.terminate()
        agents.removeValue(forKey: udid)
        return .failure(AgentError.healthCheckTimeout)
    }

    /// Send an HTTP request to the agent on the given simulator.
    func sendRequest(udid: String, path: String, body: [String: Any]) -> [String: Any] {
        let portResult = ensureAgentRunning(udid: udid)

        let port: UInt16
        switch portResult {
        case .success(let p):
            port = p
        case .failure(let error):
            return ["content": [["type": "text", "text": "Agent error: \(error)"]], "isError": true]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return ["content": [["type": "text", "text": "Failed to serialize request body"]], "isError": true]
        }

        let url = URL(string: "http://localhost:\(port)\(path)")!
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            responseData = data
            responseError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            return ["content": [["type": "text", "text": "Agent request failed: \(error.localizedDescription)"]], "isError": true]
        }

        guard let data = responseData,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["content": [["type": "text", "text": String(data: responseData ?? Data(), encoding: .utf8) ?? "Unknown response"]]]
        }

        // Format agent response as MCP text content
        let responseText = String(data: (try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])) ?? Data(), encoding: .utf8) ?? "{}"
        return ["content": [["type": "text", "text": responseText]]]
    }

    // MARK: - Health check

    private func healthCheck(port: UInt16) -> Bool {
        let url = URL(string: "http://localhost:\(port)/health")!
        let request = URLRequest(url: url, timeoutInterval: 2)

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                success = true
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        return success
    }

    // MARK: - Cleanup

    func stopAll() {
        for (_, info) in agents {
            info.process.terminate()
        }
        agents.removeAll()
    }
}

enum AgentError: Error, CustomStringConvertible {
    case missingXctestrun(String)
    case launchFailed(String)
    case healthCheckTimeout

    var description: String {
        switch self {
        case .missingXctestrun(let path):
            return "Agent xctestrun not found at \(path). Run install.sh first."
        case .launchFailed(let reason):
            return "Failed to launch agent: \(reason)"
        case .healthCheckTimeout:
            return "Agent health check timed out after 30s"
        }
    }
}
