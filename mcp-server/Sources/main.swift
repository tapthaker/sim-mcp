import Foundation

// Disable stdout buffering so MCP responses are sent immediately
setbuf(stdout, nil)

func log(_ message: String) {
    FileHandle.standardError.write(Data(("[simulator-mcp] \(message)\n").utf8))
}

log("Starting MCP server")

let server = MCPServer()
server.run()
