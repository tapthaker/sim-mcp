#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.sim-mcp"
VERSION="${SIM_MCP_VERSION:-0.3.0}"
ARCH="$(uname -m)"

# Only arm64 macOS supported
if [ "$(uname -s)" != "Darwin" ] || [ "$ARCH" != "arm64" ]; then
    echo "Error: sim-mcp requires macOS on Apple Silicon (arm64)"
    exit 1
fi

echo "Installing sim-mcp v${VERSION}..."

# If SIM_MCP_TARBALL is set, use local file; otherwise download
if [ -n "${SIM_MCP_TARBALL:-}" ]; then
    TARBALL="$SIM_MCP_TARBALL"
    echo "Using local tarball: $TARBALL"
else
    TARBALL="/tmp/sim-mcp-${VERSION}.tar.gz"
    DOWNLOAD_URL="${SIM_MCP_URL:-https://github.com/tapthaker/sim-mcp/releases/download/v${VERSION}/sim-mcp-${VERSION}-darwin-arm64.tar.gz}"
    echo "Downloading from $DOWNLOAD_URL..."
    curl -fSL "$DOWNLOAD_URL" -o "$TARBALL"
fi

# Clean previous install
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Extract
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1

echo ""
echo "Installed to $INSTALL_DIR"
echo ""
echo "Contents:"
ls -la "$INSTALL_DIR"
echo ""
echo "Add to your MCP config (e.g. claude_desktop_config.json or .claude/settings.json):"
echo ""
cat << EOF
{
  "mcpServers": {
    "sim-mcp": {
      "command": "$INSTALL_DIR/sim-mcp"
    }
  }
}
EOF
echo ""
echo "Done! You can now use sim-mcp with Claude."
