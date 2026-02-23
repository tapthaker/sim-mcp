import Foundation

// Disable stdout buffering so MCP responses are sent immediately
setbuf(stdout, nil)

// Log to stderr so it doesn't interfere with MCP protocol on stdout
func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

log("simulator-mcp: starting")

let server = MCPServer()
server.run()
