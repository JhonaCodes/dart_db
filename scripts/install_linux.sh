#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        DART_DB LINUX INSTALLER                               ║
# ║              Install native library to system directory                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# This script installs the dart_db native library to a system directory
# so it can be found by the library loader.
#
# Usage:
#   chmod +x install_linux.sh
#   sudo ./install_linux.sh

set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        DART_DB LINUX INSTALLER                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Detect script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
BINARY_PATH="$PACKAGE_ROOT/binary/linux/liboffline_first_core.so"

echo "Package root: $PACKAGE_ROOT"
echo "Binary path:  $BINARY_PATH"
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
  echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
  echo "Make sure you're running this script from the dart_db package directory."
  exit 1
fi

echo -e "${GREEN}✓ Found binary${NC}"
echo ""

# Determine installation directory
INSTALL_DIR="/usr/local/lib"
if [ ! -d "$INSTALL_DIR" ]; then
  echo -e "${YELLOW}Creating $INSTALL_DIR${NC}"
  mkdir -p "$INSTALL_DIR"
fi

# Copy library
echo "Installing library to $INSTALL_DIR..."
cp "$BINARY_PATH" "$INSTALL_DIR/liboffline_first_core.so"
chmod 755 "$INSTALL_DIR/liboffline_first_core.so"

echo -e "${GREEN}✓ Library installed${NC}"
echo ""

# Update dynamic linker cache
echo "Updating dynamic linker cache..."
if command -v ldconfig &> /dev/null; then
  ldconfig
  echo -e "${GREEN}✓ Cache updated${NC}"
else
  echo -e "${YELLOW}⚠ ldconfig not found, skipping cache update${NC}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        INSTALLATION COMPLETE                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "The dart_db library has been installed to: $INSTALL_DIR/liboffline_first_core.so"
echo ""
echo "You can now use dart_db in your Dart applications without additional configuration."
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
