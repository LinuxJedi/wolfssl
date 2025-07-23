#!/bin/bash

# Script to build wolfSSL Debian packages and extract artifacts
# This script builds both source and binary packages using Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/debian-packages"

echo "=== wolfSSL Debian Package Builder ==="
echo "Project directory: $PROJECT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Clean up previous artifacts
if [ -d "$OUTPUT_DIR" ]; then
    echo "Cleaning previous build artifacts..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# Build the Docker image and extract artifacts
echo "Building packages with Docker..."
cd "$PROJECT_DIR"

# Build the packages
docker build -f debian/test-packaging.Dockerfile -t wolfssl-debian-build .

# Extract the artifacts
echo ""
echo "Extracting build artifacts..."
docker run --rm -v "$OUTPUT_DIR:/output" wolfssl-debian-build sh -c "cp /artifacts/* /output/ 2>/dev/null || true"

# Display results
echo ""
echo "=== Build Complete ==="
echo ""
echo "Generated packages:"
ls -lh "$OUTPUT_DIR"/*.deb 2>/dev/null || echo "No .deb files found"

echo ""
echo "Generated source files:"
ls -lh "$OUTPUT_DIR"/*.{dsc,tar.*,changes} 2>/dev/null || echo "No source files found"

echo ""
echo "All artifacts saved to: $OUTPUT_DIR"
echo ""

# Provide usage information
echo "=== Usage Information ==="
echo ""
echo "To install the packages on a Debian/Ubuntu system:"
echo "  sudo dpkg -i $OUTPUT_DIR/libwolfssl*.deb"
echo "  sudo apt-get install -f  # Fix any dependency issues"
echo ""
echo "To upload to a Debian repository:"
echo "  dput <repository> $OUTPUT_DIR/wolfssl_*_source.changes"
echo ""
echo "To verify package contents:"
echo "  dpkg-deb -c $OUTPUT_DIR/libwolfssl_*.deb      # List files"
echo "  dpkg-deb -I $OUTPUT_DIR/libwolfssl_*.deb      # Show info"
echo ""
echo "To build from source package:"
echo "  dpkg-source -x $OUTPUT_DIR/wolfssl_*.dsc"
echo "  cd wolfssl-*/"
echo "  dpkg-buildpackage -b"
echo ""
