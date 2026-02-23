#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.simulator-mcp"
VERSION="${SIMULATOR_MCP_VERSION:-0.1.0}"
ARCH="$(uname -m)"

# Only arm64 macOS supported
if [ "$(uname -s)" != "Darwin" ] || [ "$ARCH" != "arm64" ]; then
    echo "Error: simulator-mcp requires macOS on Apple Silicon (arm64)"
    exit 1
fi

echo "Installing simulator-mcp v${VERSION}..."

# If SIMULATOR_MCP_TARBALL is set, use local file; otherwise download
if [ -n "${SIMULATOR_MCP_TARBALL:-}" ]; then
    TARBALL="$SIMULATOR_MCP_TARBALL"
    echo "Using local tarball: $TARBALL"
else
    TARBALL="/tmp/simulator-mcp-${VERSION}.tar.gz"
    DOWNLOAD_URL="${SIMULATOR_MCP_URL:-https://github.com/anthropics/simulator-mcp/releases/download/v${VERSION}/simulator-mcp-${VERSION}-darwin-arm64.tar.gz}"
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
    "simulator-mcp": {
      "command": "$INSTALL_DIR/simulator-mcp"
    }
  }
}
EOF
echo ""
echo "Done! You can now use simulator-mcp with Claude."
