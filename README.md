# sim-mcp

A lightweight MCP server for iOS Simulator automation. Single binary, zero dependencies — no Node.js, no WebDriverAgent, no Python, no npm packages. Just install and it works.

All you need is a Mac with Xcode installed.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tapthaker/sim-mcp/main/install.sh | bash
```

This installs to `~/.sim-mcp/`.

## Configure

Add to your MCP config:

**Claude Code** (`~/.claude/settings.json`):
```json
{
  "mcpServers": {
    "sim-mcp": {
      "command": "~/.sim-mcp/sim-mcp"
    }
  }
}
```

**Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "sim-mcp": {
      "command": "/Users/YOUR_USERNAME/.sim-mcp/sim-mcp"
    }
  }
}
```

## Requirements

- macOS (Apple Silicon)
- Xcode 15+ with iOS Simulator runtimes installed

## Tools

### Device Management
| Tool | Description |
|------|-------------|
| `list_simulators` | List all available iOS simulators |
| `boot_simulator` | Boot a simulator by UDID |
| `shutdown_simulator` | Shut down a simulator by UDID |

### App Management
| Tool | Description |
|------|-------------|
| `install_app` | Install a .app bundle on a simulator |
| `launch_app` | Launch an app by bundle ID |
| `terminate_app` | Terminate a running app |
| `list_apps` | List installed apps |

### UI Automation
| Tool | Description |
|------|-------------|
| `tap` | Tap at screen coordinates (x, y) |
| `double_tap` | Double tap at screen coordinates |
| `long_press` | Long press at coordinates with optional duration |
| `swipe` | Swipe from one point to another |
| `type_text` | Type text into the focused element |
| `press_button` | Press a hardware button (home) |
| `get_ui_tree` | Get the accessibility tree of the current UI |

### Screen & System
| Tool | Description |
|------|-------------|
| `screenshot` | Take a screenshot (returns base64 PNG) |
| `open_url` | Open a URL on the simulator |
| `set_location` | Set simulated GPS coordinates |
| `send_push_notification` | Send a push notification to an app |

## How It Works

Two-process architecture:

```
Claude <──stdio──> MCP Server (macOS binary)
                      ├── simctl ──> device mgmt, screenshots, app lifecycle
                      └── HTTP  ──> XCTest Agent (runs on simulator)
                                       └── XCUITest APIs ──> tap, swipe, type, UI tree
```

- **MCP Server**: macOS CLI binary. Speaks JSON-RPC over stdio. Routes tool calls to `simctl` or the on-device agent.
- **XCTest Agent**: Runs inside the iOS Simulator as an XCUITest. Hosts an HTTP server using `NWListener` and translates requests into XCUITest API calls.

The agent is started automatically when a UI automation tool is called for the first time on a given simulator.

## Building from Source

Requires [Bazel](https://bazel.build/) (8.x) and Xcode 15+.

```bash
# Build MCP server
bazel build //mcp-server:sim-mcp

# Build agent
bazel build //agent:AgentTest //agent:HostApp

# Package release
bash scripts/release.sh 0.1.0
```

## License

MIT
