#!/bin/bash

# Script to build Debian source package for wolfSSL with proper upstream sync
# This ensures the upstream tarball and source directory are perfectly synchronized

set -e

echo "=== wolfSSL Debian Source Package Builder ==="

# Get version and package info
FULL_VERSION=$(dpkg-parsechangelog -S Version)
VERSION=$(echo "$FULL_VERSION" | cut -d- -f1)
PACKAGE=$(dpkg-parsechangelog -S Source)
ORIG_TARBALL="../${PACKAGE}_${VERSION}.orig.tar.gz"

echo "Building source package for $PACKAGE version $FULL_VERSION (upstream: $VERSION)"

# Step 1: Clean the current source tree thoroughly
echo ""
echo "Step 1: Cleaning source tree..."
./debian/clean-for-packaging.sh

# Step 2: Create upstream tarball if it doesn't exist
echo ""
echo "Step 2: Creating upstream tarball..."
if [ ! -f "$ORIG_TARBALL" ]; then
    ./debian/create-orig-tarball.sh
else
    echo "Upstream tarball already exists: $ORIG_TARBALL"
fi

# Step 3: Build source package directly without temp directory dance
echo ""
echo "Step 3: Building source package..."

# Save current directory
CURRENT_DIR=$(pwd)

# Create a simple working directory for dpkg-buildpackage
BUILD_DIR=$(mktemp -d -p /tmp dpkg-build-XXXXXX)
WORK_DIR="$BUILD_DIR/wolfssl-$VERSION"

# Extract the orig tarball to the build directory
cd "$BUILD_DIR"
tar -xzf "$CURRENT_DIR/$ORIG_TARBALL"

# Copy the upstream tarball to the build directory where dpkg-buildpackage expects it
cp "$CURRENT_DIR/$ORIG_TARBALL" .

# Copy debian directory to extracted source
cp -r "$CURRENT_DIR/debian" "$WORK_DIR/"

# Ensure proper permissions
chmod +x "$WORK_DIR/debian/rules"

# Build the source package
echo "Running dpkg-buildpackage -S -us -uc..."
cd "$WORK_DIR"
dpkg-buildpackage -S -us -uc

# Copy results back to original location
echo ""
echo "Step 4: Copying results back..."
cp "$BUILD_DIR"/*.dsc "$CURRENT_DIR/../"
cp "$BUILD_DIR"/*.debian.tar.* "$CURRENT_DIR/../"
cp "$BUILD_DIR"/*.changes "$CURRENT_DIR/../" 2>/dev/null || true
cp "$BUILD_DIR"/*.buildinfo "$CURRENT_DIR/../" 2>/dev/null || true

# Return to original directory and clean up
cd "$CURRENT_DIR"
rm -rf "$BUILD_DIR"

echo ""
echo "=== Source Package Built Successfully ==="
echo ""
echo "Generated files:"
echo "- ${PACKAGE}_${VERSION}.orig.tar.gz"
echo "- ${PACKAGE}_${FULL_VERSION}.dsc"
echo "- ${PACKAGE}_${FULL_VERSION}.debian.tar.xz"
echo "- ${PACKAGE}_${FULL_VERSION}.changes"
echo ""
echo "To build binary packages:"
echo "1. Extract: dpkg-source -x ${PACKAGE}_${FULL_VERSION}.dsc"
echo "2. Build: cd ${PACKAGE}-${VERSION} && dpkg-buildpackage -b"
echo ""
echo "Or upload to a build system that accepts Debian source packages."
