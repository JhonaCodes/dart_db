#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                   DART_DB LINUX DIAGNOSTIC TOOL                              ║
# ║              Diagnose and fix library loading issues                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# This script helps diagnose why liboffline_first_core.so cannot be loaded
#
# Usage:
#   bash diagnose_linux.sh

set +e  # Don't exit on errors, we want to see all issues

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                   DART_DB LINUX DIAGNOSTIC TOOL                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find the library
echo -e "${BLUE}Searching for liboffline_first_core.so...${NC}"
LIBRARY_PATH=$(find ~/.pub-cache -name "liboffline_first_core.so" 2>/dev/null | head -1)

if [ -z "$LIBRARY_PATH" ]; then
    echo -e "${RED}✗ Library not found in ~/.pub-cache${NC}"
    echo ""
    echo "Please make sure you have added dart_db to your project:"
    echo "  dart pub add dart_db"
    echo "  dart pub get"
    exit 1
fi

echo -e "${GREEN}✓ Found library at:${NC}"
echo "  $LIBRARY_PATH"
echo ""

# Check file exists
if [ ! -f "$LIBRARY_PATH" ]; then
    echo -e "${RED}✗ File does not exist (broken symlink?)${NC}"
    exit 1
fi

echo -e "${BLUE}Checking file information...${NC}"
echo ""

# Check file type
echo "File type:"
file "$LIBRARY_PATH"
echo ""

# Check file permissions
echo "File permissions:"
ls -lah "$LIBRARY_PATH"
echo ""

PERMS=$(stat -c "%a" "$LIBRARY_PATH" 2>/dev/null || stat -f "%Lp" "$LIBRARY_PATH" 2>/dev/null)
if [[ "$PERMS" == *"755"* ]] || [[ "$PERMS" == *"777"* ]]; then
    echo -e "${GREEN}✓ Permissions are OK${NC}"
else
    echo -e "${YELLOW}⚠ Permissions might be incorrect (found: $PERMS)${NC}"
    echo ""
    echo "To fix permissions, run:"
    echo -e "${BLUE}  chmod +x $LIBRARY_PATH${NC}"
fi
echo ""

# Check dependencies
echo -e "${BLUE}Checking library dependencies...${NC}"
echo ""

if command -v ldd &> /dev/null; then
    LDD_OUTPUT=$(ldd "$LIBRARY_PATH" 2>&1)
    echo "$LDD_OUTPUT"
    echo ""

    # Check for missing dependencies
    if echo "$LDD_OUTPUT" | grep -q "not found"; then
        echo -e "${RED}✗ MISSING DEPENDENCIES DETECTED${NC}"
        echo ""
        echo "Missing libraries:"
        echo "$LDD_OUTPUT" | grep "not found" | awk '{print "  - " $1}'
        echo ""
        echo "This is the most likely cause of the loading error."
        echo ""
        echo -e "${YELLOW}To fix missing dependencies:${NC}"
        echo ""

        # Detect distro and suggest commands
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    echo "For Ubuntu/Debian:"
                    echo -e "${BLUE}  sudo apt-get update${NC}"
                    echo -e "${BLUE}  sudo apt-get install -y libc6 libgcc-s1 libstdc++6${NC}"
                    ;;
                fedora|rhel|centos)
                    echo "For Fedora/RHEL/CentOS:"
                    echo -e "${BLUE}  sudo yum install -y glibc libgcc libstdc++${NC}"
                    ;;
                alpine)
                    echo "For Alpine Linux:"
                    echo -e "${BLUE}  apk add --no-cache libc6-compat libgcc libstdc++${NC}"
                    ;;
                *)
                    echo "For your Linux distribution, install:"
                    echo "  - glibc (libc6)"
                    echo "  - libgcc"
                    echo "  - libstdc++"
                    ;;
            esac
        fi
        echo ""
        HAS_MISSING=true
    else
        echo -e "${GREEN}✓ All dependencies are satisfied${NC}"
        echo ""
        HAS_MISSING=false
    fi
else
    echo -e "${YELLOW}⚠ ldd command not found, cannot check dependencies${NC}"
    echo ""
    HAS_MISSING=false
fi

# Check if we can load it with a simple test
echo -e "${BLUE}Attempting to load library with dlopen...${NC}"
echo ""

# Create a simple C program to test loading
TEST_PROGRAM=$(mktemp)
cat > "${TEST_PROGRAM}.c" << 'EOF'
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char* argv[]) {
    void* handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        fprintf(stderr, "Error: %s\n", dlerror());
        return 1;
    }
    printf("Success: Library loaded successfully\n");
    dlclose(handle);
    return 0;
}
EOF

# Try to compile and run the test
if command -v gcc &> /dev/null; then
    gcc "${TEST_PROGRAM}.c" -o "${TEST_PROGRAM}" -ldl 2>/dev/null
    if [ $? -eq 0 ]; then
        LOAD_RESULT=$("${TEST_PROGRAM}" "$LIBRARY_PATH" 2>&1)
        LOAD_EXIT_CODE=$?

        echo "$LOAD_RESULT"
        echo ""

        if [ $LOAD_EXIT_CODE -eq 0 ]; then
            echo -e "${GREEN}✓ Library can be loaded successfully!${NC}"
            echo ""
            echo "The library itself is fine. The issue might be with how Dart is trying to load it."
            echo ""
            echo -e "${YELLOW}Recommended solution:${NC}"
            echo "Copy the library to a system directory where Dart can find it:"
            echo ""
            echo -e "${BLUE}  sudo cp $LIBRARY_PATH /usr/local/lib/${NC}"
            echo -e "${BLUE}  sudo ldconfig${NC}"
        else
            echo -e "${RED}✗ Library cannot be loaded${NC}"
            echo ""
            if [ "$HAS_MISSING" = true ]; then
                echo "This is likely due to missing dependencies (see above)."
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Could not compile test program${NC}"
    fi

    # Cleanup
    rm -f "${TEST_PROGRAM}.c" "${TEST_PROGRAM}"
else
    echo -e "${YELLOW}⚠ gcc not found, cannot test library loading${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}RECOMMENDED ACTIONS:${NC}"
echo ""

if [ "$HAS_MISSING" = true ]; then
    echo "1. Install missing dependencies (see commands above)"
    echo "2. Run this diagnostic again to verify"
else
    echo "1. Install the library to system directory (recommended):"
    echo ""
    echo -e "   ${BLUE}sudo cp $LIBRARY_PATH /usr/local/lib/${NC}"
    echo -e "   ${BLUE}sudo ldconfig${NC}"
    echo ""
    echo "2. OR use the provided install script:"
    echo ""
    PACKAGE_DIR=$(dirname $(dirname "$LIBRARY_PATH"))
    echo -e "   ${BLUE}cd $PACKAGE_DIR${NC}"
    echo -e "   ${BLUE}sudo scripts/install_linux.sh${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
