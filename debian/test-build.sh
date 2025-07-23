#!/bin/bash

# Simple build test script for wolfSSL Debian packaging
# This script can be used to test the packaging in a Docker container

set -e

echo "=== wolfSSL Debian Packaging Test ==="

# Check if we're in the right directory
if [ ! -f "debian/rules" ]; then
    echo "Error: debian/rules not found. Please run this script from the wolfSSL source root."
    exit 1
fi

echo "1. Checking build dependencies..."
dpkg-checkbuilddeps || {
    echo "Missing build dependencies. Install them with:"
    echo "sudo apt-get install $(dpkg-checkbuilddeps 2>&1 | sed 's/.*: //')"
    exit 1
}

echo "2. Running build preparation..."
if [ -f "debian/prepare-build.sh" ]; then
    ./debian/prepare-build.sh
fi

echo "3. Cleaning any previous builds..."
debian/rules clean || true
rm -f ../wolfssl_* ../libwolfssl* || true

echo "4. Generating configure script if needed..."
if [ ! -f configure ]; then
    echo "Running autogen.sh..."
    ./autogen.sh
fi

echo "5. Creating upstream tarball..."
./debian/create-orig-tarball.sh

echo "6. Building source package..."
dpkg-buildpackage -S -us -uc

echo "7. Building binary packages..."
dpkg-buildpackage -b -us -uc

echo "8. Listing generated files..."
echo "Source package files:"
FULL_VERSION=$(dpkg-parsechangelog -S Version)
VERSION=$(echo "$FULL_VERSION" | cut -d- -f1)
ls -la ../wolfssl_${VERSION}.orig.tar.gz ../wolfssl_${FULL_VERSION}.dsc ../wolfssl_${FULL_VERSION}.debian.tar.* ../wolfssl_${FULL_VERSION}.changes 2>/dev/null || echo "No source files found"
echo "Binary package files:"
ls -la ../libwolfssl*.deb 2>/dev/null || echo "No binary packages found"

echo "9. Testing package installation..."
if [ "$EUID" -eq 0 ]; then
    echo "Installing packages as root..."
    dpkg -i ../libwolfssl*.deb || apt-get install -f -y

    echo "10. Verifying installation..."
    pkg-config --exists wolfssl && echo "✓ pkg-config found" || echo "✗ pkg-config NOT found"
    ldconfig -p | grep -q wolfssl && echo "✓ Library found in ldconfig" || echo "✗ Library NOT found"
    test -f /usr/include/wolfssl/ssl.h && echo "✓ Headers installed" || echo "✗ Headers NOT installed"

    echo "11. Package contents:"
    dpkg -L libwolfssl | head -20
    echo "..."
    dpkg -L libwolfssl-dev | head -20
else
    echo "Skipping installation test (not running as root)"
    echo "To test installation, run as root or use Docker:"
    echo "docker build -f debian/test-packaging.Dockerfile -t wolfssl-test ."
    echo ""
    echo "Source package files created for upload/distribution:"
    FULL_VERSION=$(dpkg-parsechangelog -S Version)
    VERSION=$(echo "$FULL_VERSION" | cut -d- -f1)
    ls -la ../wolfssl_${FULL_VERSION}.dsc ../wolfssl_${VERSION}.orig.tar.gz ../wolfssl_${FULL_VERSION}.debian.tar.* 2>/dev/null || true
fi

echo "=== Test completed ==="
