import Foundation
import Network

/// Lightweight HTTP server using NWListener for the XCTest agent process.
/// Runs on a configurable port (env AGENT_PORT, default 8100).
class HTTPServer {
    typealias RouteHandler = (_ body: [String: Any]) -> (Int, [String: Any])

    private var listener: NWListener?
    private var routes: [String: RouteHandler] = [:]
    let port: UInt16

    init(port: UInt16? = nil) {
        if let port = port {
            self.port = port
        } else if let envPort = ProcessInfo.processInfo.environment["AGENT_PORT"],
                  let p = UInt16(envPort) {
            self.port = p
        } else {
            self.port = 8100
        }
    }

    func addRoute(_ path: String, handler: @escaping RouteHandler) {
        routes[path] = handler
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                NSLog("[AgentHTTP] Listening on port \(self.port)")
            case .failed(let error):
                NSLog("[AgentHTTP] Listener failed: \(error)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(on: connection, accumulated: Data())
    }

    private func receiveData(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            var buffer = accumulated
            if let data = data {
                buffer.append(data)
            }

            // Try to parse a complete HTTP request
            if let request = self.parseHTTPRequest(from: buffer) {
                self.dispatch(request: request, on: connection)
            } else if isComplete || error != nil {
                // Connection closed before full request
                connection.cancel()
            } else {
                // Need more data
                self.receiveData(on: connection, accumulated: buffer)
            }
        }
    }

    // MARK: - HTTP parsing

    struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private func parseHTTPRequest(from data: Data) -> HTTPRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }

        // Find header/body separator
        guard let headerEndRange = str.range(of: "\r\n\r\n") else { return nil }

        let headerSection = String(str[str.startIndex..<headerEndRange.lowerBound])
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = str.index(headerEndRange.upperBound, offsetBy: 0)
        let bodyString = String(str[bodyStart...])
        let bodyData = bodyString.data(using: .utf8) ?? Data()

        // Check if we have enough body data
        if bodyData.count < contentLength {
            return nil // Need more data
        }

        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: Data(bodyData.prefix(contentLength))
        )
    }

    // MARK: - Dispatch

    private func dispatch(request: HTTPRequest, on connection: NWConnection) {
        let path = request.path.split(separator: "?").first.map(String.init) ?? request.path

        guard let handler = routes[path] else {
            sendResponse(connection: connection, status: 404, body: ["error": "Not found: \(path)"])
            return
        }

        // Parse JSON body
        var jsonBody: [String: Any] = [:]
        if !request.body.isEmpty {
            if let parsed = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] {
                jsonBody = parsed
            }
        }

        let (status, responseBody) = handler(jsonBody)
        sendResponse(connection: connection, status: status, body: responseBody)
    }

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()

        var response = "HTTP/1.1 \(status) \(statusText)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(jsonData.count)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"

        var responseData = Data(response.utf8)
        responseData.append(jsonData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
