#!/bin/bash

# Script to create Debian source package files for wolfSSL
# This generates the .orig.tar.gz, .debian.tar.xz, and .dsc files

set -e

# Get the version from the changelog
FULL_VERSION=$(dpkg-parsechangelog -S Version)
VERSION=$(echo "$FULL_VERSION" | cut -d- -f1)
PACKAGE=$(dpkg-parsechangelog -S Source)

echo "Creating Debian source package for $PACKAGE version $FULL_VERSION (upstream: $VERSION)"

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
ORIG_DIR="$TEMP_DIR/${PACKAGE}-${VERSION}"
WORK_DIR=$(pwd)

echo "Working in temporary directory: $TEMP_DIR"

# Copy source to temporary directory, excluding debian directory and other unwanted files
echo "Copying source files..."
mkdir -p "$ORIG_DIR"
rsync -av \
    --exclude='.git*' \
    --exclude='debian/' \
    --exclude='*.tar.gz' \
    --exclude='*.deb' \
    --exclude='*.dsc' \
    --exclude='*.changes' \
    --exclude='*.buildinfo' \
    --exclude='autom4te.cache/' \
    --exclude='config.log' \
    --exclude='config.status' \
    --exclude='config.h' \
    --exclude='Makefile' \
    --exclude='stamp-h*' \
    --exclude='libtool' \
    --exclude='.build_params' \
    --exclude='out*.log' \
    --exclude='test.log' \
    --exclude='*.o' \
    --exclude='*.lo' \
    --exclude='*.la' \
    --exclude='.libs/' \
    --exclude='src/.libs/' \
    --exclude='wolfcrypt/src/.libs/' \
    ./ "$ORIG_DIR/"

# Create the orig tarball
echo "Creating ${PACKAGE}_${VERSION}.orig.tar.gz..."
cd "$TEMP_DIR"
tar --exclude-vcs -czf "${WORK_DIR}/../${PACKAGE}_${VERSION}.orig.tar.gz" "${PACKAGE}-${VERSION}/"

# Copy debian directory to the source
echo "Copying debian directory..."
cp -r "$WORK_DIR/debian" "$ORIG_DIR/"

# Create the source package
echo "Creating Debian source package..."
cd "$ORIG_DIR"

# Build source package
dpkg-buildpackage -S -us -uc -d

# Copy results back
echo "Copying results..."
cp "$TEMP_DIR"/*.dsc "$WORK_DIR/../"
cp "$TEMP_DIR"/*.debian.tar.* "$WORK_DIR/../"
cp "$TEMP_DIR"/*.changes "$WORK_DIR/../" 2>/dev/null || true
cp "$TEMP_DIR"/*.buildinfo "$WORK_DIR/../" 2>/dev/null || true

# Clean up
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "Debian source package files created in parent directory:"
echo "- ${PACKAGE}_${VERSION}.orig.tar.gz"
echo "- ${PACKAGE}_${FULL_VERSION}.dsc"
echo "- ${PACKAGE}_${FULL_VERSION}.debian.tar.xz"
echo ""
echo "To build binary packages from these files:"
echo "1. Extract: dpkg-source -x ${PACKAGE}_${FULL_VERSION}.dsc"
echo "2. Build: cd ${PACKAGE}-${VERSION} && dpkg-buildpackage -b"
echo ""
echo "Or upload the source package to a build system that supports Debian."
