import Foundation

/// Wraps `xcrun simctl` commands via Process().
class SimulatorManager {

    // MARK: - Device Management

    func listSimulators() -> [String: Any] {
        let (exitCode, stdout, stderr) = runSimctl(["list", "devices", "available", "--json"])
        if exitCode == 0, let data = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return ["content": [["type": "text", "text": String(data: (try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])) ?? Data(), encoding: .utf8) ?? ""]]]
        }
        return errorContent("simctl list failed: \(stderr)")
    }

    func bootSimulator(udid: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["boot", udid])
        if exitCode == 0 {
            return successContent("Simulator \(udid) booted")
        }
        return errorContent("Boot failed: \(stderr)")
    }

    func shutdownSimulator(udid: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["shutdown", udid])
        if exitCode == 0 {
            return successContent("Simulator \(udid) shut down")
        }
        return errorContent("Shutdown failed: \(stderr)")
    }

    // MARK: - App Management

    func installApp(udid: String, appPath: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["install", udid, appPath])
        if exitCode == 0 {
            return successContent("App installed on \(udid)")
        }
        return errorContent("Install failed: \(stderr)")
    }

    func launchApp(udid: String, bundleId: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["launch", udid, bundleId])
        if exitCode == 0 {
            return successContent("App \(bundleId) launched on \(udid)")
        }
        return errorContent("Launch failed: \(stderr)")
    }

    func terminateApp(udid: String, bundleId: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["terminate", udid, bundleId])
        if exitCode == 0 {
            return successContent("App \(bundleId) terminated on \(udid)")
        }
        return errorContent("Terminate failed: \(stderr)")
    }

    func listApps(udid: String) -> [String: Any] {
        let (exitCode, stdout, stderr) = runSimctl(["listapps", udid])
        if exitCode == 0 {
            return ["content": [["type": "text", "text": stdout]]]
        }
        return errorContent("listapps failed: \(stderr)")
    }

    // MARK: - Screen & System

    func screenshot(udid: String) -> [String: Any] {
        let tmpPath = NSTemporaryDirectory() + "simctl_screenshot_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let (exitCode, _, stderr) = runSimctl(["io", udid, "screenshot", "--type=png", tmpPath])
        if exitCode == 0, let data = try? Data(contentsOf: URL(fileURLWithPath: tmpPath)) {
            let base64 = data.base64EncodedString()
            return ["content": [["type": "image", "data": base64, "mimeType": "image/png"]]]
        }
        return errorContent("Screenshot failed: \(stderr)")
    }

    func openURL(udid: String, url: String) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["openurl", udid, url])
        if exitCode == 0 {
            return successContent("Opened URL: \(url)")
        }
        return errorContent("openurl failed: \(stderr)")
    }

    func setLocation(udid: String, lat: Double, lon: Double) -> [String: Any] {
        let (exitCode, _, stderr) = runSimctl(["location", udid, "set", "\(lat),\(lon)"])
        if exitCode == 0 {
            return successContent("Location set to \(lat), \(lon)")
        }
        return errorContent("set location failed: \(stderr)")
    }

    func sendPushNotification(udid: String, bundleId: String, title: String, body: String, badge: Int?) -> [String: Any] {
        var payload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": title,
                    "body": body
                ] as [String: Any]
            ] as [String: Any]
        ]
        if let badge = badge {
            var aps = payload["aps"] as! [String: Any]
            aps["badge"] = badge
            payload["aps"] = aps
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return errorContent("Failed to create push payload")
        }

        // Write payload to temp file and pipe to simctl
        let tmpPath = NSTemporaryDirectory() + "push_\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        do {
            try jsonString.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            return errorContent("Failed to write push payload: \(error)")
        }

        let (exitCode, _, stderr) = runSimctl(["push", udid, bundleId, tmpPath])
        if exitCode == 0 {
            return successContent("Push notification sent to \(bundleId)")
        }
        return errorContent("push failed: \(stderr)")
    }

    // MARK: - Helpers

    private func runSimctl(_ args: [String]) -> (Int32, String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", "Failed to launch simctl: \(error)")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    private func successContent(_ message: String) -> [String: Any] {
        return ["content": [["type": "text", "text": message]]]
    }

    private func errorContent(_ message: String) -> [String: Any] {
        return ["content": [["type": "text", "text": message]], "isError": true]
    }
}
