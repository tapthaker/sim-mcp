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

        let xctestrunTemplate = "\(installDir)/AgentTest.xctestrun"

        guard FileManager.default.fileExists(atPath: xctestrunTemplate) else {
            return .failure(AgentError.missingXctestrun(xctestrunTemplate))
        }

        // Discover Xcode developer path for platform frameworks
        let xcodeDev = discoverXcodeDeveloperPath()
        let platformFrameworks = "\(xcodeDev)/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks"
        let platformUsrLib = "\(xcodeDev)/Platforms/iPhoneSimulator.platform/Developer/usr/lib"

        // Create a per-port copy of the xctestrun with the correct AGENT_PORT,
        // resolve __TESTROOT__ to the install directory (since the temp copy
        // lives in a different directory than the runner/xctest bundles),
        // and inject Xcode platform paths for XCTest.framework resolution
        let xctestrunPath = NSTemporaryDirectory() + "sim-mcp-agent-\(port).xctestrun"
        do {
            var plistData = try Data(contentsOf: URL(fileURLWithPath: xctestrunTemplate))
            if var plistStr = String(data: plistData, encoding: .utf8) {
                plistStr = plistStr.replacingOccurrences(of: "<string>8100</string>", with: "<string>\(port)</string>")

                // Inject Xcode platform paths into DYLD vars before resolving __TESTROOT__
                plistStr = plistStr.replacingOccurrences(
                    of: "<key>DYLD_FRAMEWORK_PATH</key>\n            <string>__TESTROOT__/AgentTest-Runner.app/Frameworks</string>",
                    with: "<key>DYLD_FRAMEWORK_PATH</key>\n            <string>__TESTROOT__/AgentTest-Runner.app/Frameworks:\(platformFrameworks)</string>"
                )
                plistStr = plistStr.replacingOccurrences(
                    of: "<key>DYLD_LIBRARY_PATH</key>\n            <string>__TESTROOT__/AgentTest-Runner.app/Frameworks</string>",
                    with: "<key>DYLD_LIBRARY_PATH</key>\n            <string>__TESTROOT__/AgentTest-Runner.app/Frameworks:\(platformUsrLib):\(platformFrameworks)</string>"
                )

                // Resolve __TESTROOT__ to actual install directory
                plistStr = plistStr.replacingOccurrences(of: "__TESTROOT__", with: installDir)
                plistData = Data(plistStr.utf8)
            }
            try plistData.write(to: URL(fileURLWithPath: xctestrunPath))
        } catch {
            return .failure(AgentError.launchFailed("Failed to prepare xctestrun: \(error)"))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "test-without-building",
            "-xctestrun", xctestrunPath,
            "-destination", "platform=iOS Simulator,id=\(udid)",
        ]

        process.environment = ProcessInfo.processInfo.environment

        // Redirect stdout/stderr to log files so they don't interfere with MCP stdio
        let logDir = NSTemporaryDirectory() + "sim-mcp-logs"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        // Truncate existing log file for a clean start
        let logPath = "\(logDir)/agent-\(udid).log"
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let logFile = FileHandle(forWritingAtPath: logPath)!

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
        var request = URLRequest(url: url, timeoutInterval: 60)
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

    // MARK: - Xcode discovery

    private func discoverXcodeDeveloperPath() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return path
            }
        } catch {}
        // Fallback to default Xcode path
        return "/Applications/Xcode.app/Contents/Developer"
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
