#!/bin/bash

# Simple script to create upstream orig tarball for wolfSSL Debian packaging
# This creates the .orig.tar.gz needed for 3.0 (quilt) source format

set -e

# Get version and package name
FULL_VERSION=$(dpkg-parsechangelog -S Version)
VERSION=$(echo "$FULL_VERSION" | cut -d- -f1)
PACKAGE=$(dpkg-parsechangelog -S Source)
ORIG_TARBALL="../${PACKAGE}_${VERSION}.orig.tar.gz"

echo "Creating upstream tarball: $ORIG_TARBALL"

# Run preparation to ensure debian/control exists
if [ -f "debian/prepare-build.sh" ]; then
    echo "Running build preparation..."
    ./debian/prepare-build.sh
fi

# Check if tarball already exists
if [ -f "$ORIG_TARBALL" ]; then
    echo "Upstream tarball already exists: $ORIG_TARBALL"
    echo "Remove it first if you want to recreate it."
    exit 1
fi

# Create a clean copy without debian/ directory and build artifacts
echo "Creating clean source tree..."

# Use git archive if we're in a git repository
if [ -d .git ]; then
    echo "Using git archive to create clean source..."
    git archive --format=tar --prefix="${PACKAGE}-${VERSION}/" HEAD | gzip > "$ORIG_TARBALL"
else
    echo "Creating tarball from current directory..."
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    SOURCE_DIR="$TEMP_DIR/${PACKAGE}-${VERSION}"

    # Copy source excluding debian and build artifacts
    # We exclude debian entirely to avoid control file generation conflicts
    mkdir -p "$SOURCE_DIR"
    tar --exclude='./debian' \
        --exclude='./.git*' \
        --exclude='./autom4te.cache' \
        --exclude='./config.log' \
        --exclude='./config.status' \
        --exclude='./config.h' \
        --exclude='./Makefile' \
        --exclude='./stamp-h*' \
        --exclude='./libtool' \
        --exclude='./.build_params' \
        --exclude='./out*.log' \
        --exclude='./test.log' \
        --exclude='./*.tar.gz' \
        --exclude='./*.deb' \
        --exclude='./*.dsc' \
        --exclude='./*.changes' \
        --exclude='./*.buildinfo' \
        --exclude='./src/.libs' \
        --exclude='./wolfcrypt/src/.libs' \
        --exclude='./.libs' \
        --exclude='./**/*.o' \
        --exclude='./**/*.lo' \
        --exclude='./**/*.la' \
        --exclude='./**/*.so' \
        --exclude='./**/*.so.*' \
        --exclude='./wrapper/Ada/obj' \
        --exclude='./wrapper/Ada/lib' \
        --exclude='./**/*.stdout' \
        --exclude='./**/*.stderr' \
        --exclude='./**/*~' \
        --exclude='./**/.deps' \
        --exclude='./**/.dirstamp' \
        --exclude='./wolfssl-*.tar.gz' \
        --exclude='./aminclude.am' \
        --exclude='./certeccrsa.der' \
        --exclude='./tests/bio_write_test.txt' \
        --exclude='./tests/*.tmp' \
        --exclude='./wolfcrypt/benchmark/*.info' \
        --exclude='./**/*.gcda' \
        --exclude='./**/*.gcno' \
        --exclude='./**/*.gcov' \
        --exclude='./**/*.profdata' \
        --exclude='./build-aux/ltmain.sh' \
        --exclude='./m4/libtool.m4' \
        --exclude='./m4/ltoptions.m4' \
        --exclude='./m4/ltsugar.m4' \
        --exclude='./m4/ltversion.m4' \
        --exclude='./m4/lt~obsolete.m4' \
        --exclude='./aclocal.m4' \
        --exclude='./support/wolfssl.pc' \
        --exclude='./wolfssl-config' \
        --exclude='./wolfssl/options.h' \
        --exclude='./config.in' \
        --exclude='./wolfcrypt/src/fips_test.c' \
        --exclude='./wolfcrypt/src/wolfcrypt_first.c' \
        --exclude='./wolfcrypt/src/wolfcrypt_last.c' \
        --exclude='./wolfcrypt/test/test_paths.h' \
        --exclude='./rpm/spec' \
        --exclude='./certeccrsa.pem' \
        --exclude='./ecc-key.pem' \
        --exclude='./test-write-dhparams.pem' \
        -cf - . | (cd "$SOURCE_DIR" && tar -xf -)

    # Create the tarball
    cd "$TEMP_DIR"
    tar -czf "$ORIG_TARBALL" "${PACKAGE}-${VERSION}/"

    # Clean up
    rm -rf "$TEMP_DIR"
fi

echo "Created: $ORIG_TARBALL"
echo ""
echo "Now you can create the source package with:"
echo "  dpkg-buildpackage -S -us -uc"
echo ""
echo "This will generate:"
echo "  - ${PACKAGE}_${FULL_VERSION}.dsc"
echo "  - ${PACKAGE}_${FULL_VERSION}.debian.tar.xz"
echo "  - ${PACKAGE}_${FULL_VERSION}_source.changes"
