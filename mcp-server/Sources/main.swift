import Foundation

let version = "0.4.0"

// Handle --version / -v flag
let args = CommandLine.arguments
if args.contains("--version") || args.contains("-v") {
    print("sim-mcp \(version)")
    exit(0)
}

// Disable stdout buffering so MCP responses are sent immediately
setbuf(stdout, nil)

func log(_ message: String) {
    FileHandle.standardError.write(Data(("[sim-mcp] \(message)\n").utf8))
}

log("Starting MCP server")

let server = MCPServer()
server.run()
