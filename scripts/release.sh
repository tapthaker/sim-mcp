#!/bin/bash
set -euo pipefail

# Build both targets in optimized mode
echo "Building MCP server..."
bazel build --compilation_mode=opt //mcp-server:simulator-mcp

echo "Building Agent..."
bazel build --compilation_mode=opt //agent:AgentTest //agent:HostApp

# Find build outputs
OUTPUT_PATH=$(bazel info output_path 2>/dev/null)
MCP_BIN=$(find "$OUTPUT_PATH" -path "*opt*macos*/bin/mcp-server/simulator-mcp" ! -path "*runfiles*" | head -1)

# Find iOS outputs — they're in a different output directory for iOS simulator builds
AGENT_ZIP=$(find "$(bazel info output_path 2>/dev/null)" -path "*/ios_sim_arm64*opt*/bin/agent/AgentTest.zip" ! -path "*runfiles*" | head -1)
HOST_IPA=$(find "$(bazel info output_path 2>/dev/null)" -path "*/ios_sim_arm64*opt*/bin/agent/HostApp.ipa" ! -path "*runfiles*" | head -1)

if [ -z "$MCP_BIN" ] || [ -z "$AGENT_ZIP" ] || [ -z "$HOST_IPA" ]; then
    echo "Error: Could not find build artifacts"
    echo "  MCP_BIN=$MCP_BIN"
    echo "  AGENT_ZIP=$AGENT_ZIP"
    echo "  HOST_IPA=$HOST_IPA"
    exit 1
fi

# Create staging directory
DIST_DIR="$(pwd)/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/simulator-mcp"

# Copy MCP server binary
cp "$MCP_BIN" "$DIST_DIR/simulator-mcp/"

# Extract agent test bundle
unzip -o "$AGENT_ZIP" -d "$DIST_DIR/simulator-mcp/"

# Extract host app from IPA
mkdir -p /tmp/ipa_extract
unzip -o "$HOST_IPA" -d /tmp/ipa_extract
cp -R /tmp/ipa_extract/Payload/HostApp.app "$DIST_DIR/simulator-mcp/"
rm -rf /tmp/ipa_extract

# Generate xctestrun plist
cat > "$DIST_DIR/simulator-mcp/AgentTest.xctestrun" << 'XCTESTRUN'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>__xctestrun_metadata__</key>
    <dict>
        <key>FormatVersion</key>
        <integer>1</integer>
    </dict>
    <key>AgentTest</key>
    <dict>
        <key>TestBundlePath</key>
        <string>__TESTHOST__/PlugIns/AgentTest.xctest</string>
        <key>TestHostPath</key>
        <string>__PLATFORMPATH__/HostApp.app</string>
        <key>TestHostBundleIdentifier</key>
        <string>com.simulator-mcp.HostApp</string>
        <key>IsUITestBundle</key>
        <true/>
        <key>IsXCTRunnerHostedTestBundle</key>
        <true/>
        <key>TestingEnvironmentVariables</key>
        <dict>
            <key>AGENT_PORT</key>
            <string>$(AGENT_PORT)</string>
        </dict>
        <key>CommandLineArguments</key>
        <array/>
        <key>OnlyTestIdentifiers</key>
        <array>
            <string>AgentTest/testRunAgent</string>
        </array>
    </dict>
</dict>
</plist>
XCTESTRUN

echo ""
echo "Staging directory: $DIST_DIR/simulator-mcp/"
ls -la "$DIST_DIR/simulator-mcp/"

# Create tarball
VERSION="${1:-0.1.0}"
TARBALL="$DIST_DIR/simulator-mcp-${VERSION}-darwin-arm64.tar.gz"
tar -czf "$TARBALL" -C "$DIST_DIR" simulator-mcp
echo ""
echo "Release tarball: $TARBALL"
echo "Contents:"
tar -tzf "$TARBALL"
