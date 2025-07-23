#!/bin/bash

# Comprehensive cleanup script for wolfSSL Debian packaging
# This script ensures the source tree is in a clean state before packaging

set -e

echo "Cleaning wolfSSL source tree for Debian packaging..."

# Remove all build artifacts
echo "Removing build artifacts..."
find . -name "*.o" -delete 2>/dev/null || true
find . -name "*.lo" -delete 2>/dev/null || true
find . -name "*.la" -delete 2>/dev/null || true
find . -name "*.so" -delete 2>/dev/null || true
find . -name "*.so.*" -delete 2>/dev/null || true
find . -name "*.a" -delete 2>/dev/null || true

# Remove build directories
echo "Removing build directories..."
rm -rf .libs src/.libs wolfcrypt/src/.libs 2>/dev/null || true
rm -rf wrapper/Ada/obj wrapper/Ada/lib 2>/dev/null || true
find . -name ".deps" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove autotools generated files
echo "Removing autotools generated files..."
rm -f aclocal.m4 2>/dev/null || true
rm -f build-aux/ltmain.sh 2>/dev/null || true
rm -f m4/libtool.m4 m4/ltoptions.m4 m4/ltsugar.m4 m4/ltversion.m4 m4/lt~obsolete.m4 2>/dev/null || true

# Remove configure generated files
echo "Removing configure generated files..."
rm -f config.h config.log config.status 2>/dev/null || true
rm -f config.in 2>/dev/null || true
rm -f libtool 2>/dev/null || true
rm -f stamp-h stamp-h1 2>/dev/null || true
rm -f .build_params 2>/dev/null || true
rm -f aminclude.am 2>/dev/null || true

# Remove generated Makefiles
echo "Removing generated Makefiles..."
find . -name "Makefile" -not -path "./debian/*" -delete 2>/dev/null || true
find . -name "Makefile.in" -not -path "./debian/*" -delete 2>/dev/null || true

# Remove generated config and pkg-config files
echo "Removing generated configuration files..."
rm -f support/wolfssl.pc 2>/dev/null || true
rm -f wolfssl-config 2>/dev/null || true
rm -f wolfssl/options.h 2>/dev/null || true

# Remove generated source files
echo "Removing generated source files..."
rm -f wolfcrypt/src/fips_test.c 2>/dev/null || true
rm -f wolfcrypt/src/wolfcrypt_first.c 2>/dev/null || true
rm -f wolfcrypt/src/wolfcrypt_last.c 2>/dev/null || true
rm -f wolfcrypt/src/async.c 2>/dev/null || true
rm -f wolfcrypt/src/fips.c 2>/dev/null || true
rm -f wolfcrypt/src/selftest.c 2>/dev/null || true
rm -f wolfcrypt/src/port/cavium/cavium_nitrox.c 2>/dev/null || true
rm -f wolfcrypt/src/port/intel/quickassist.c 2>/dev/null || true
rm -f wolfcrypt/src/port/intel/quickassist_mem.c 2>/dev/null || true

# Remove generated header files
echo "Removing generated header files..."
rm -f wolfcrypt/test/test_paths.h 2>/dev/null || true
rm -f wolfssl/wolfcrypt/async.h 2>/dev/null || true
rm -f wolfssl/wolfcrypt/fips.h 2>/dev/null || true
rm -f wolfssl/wolfcrypt/port/cavium/cavium_nitrox.h 2>/dev/null || true
rm -f wolfssl/wolfcrypt/port/intel/quickassist.h 2>/dev/null || true
rm -f wolfssl/wolfcrypt/port/intel/quickassist_mem.h 2>/dev/null || true

# Remove test artifacts and temporary files
echo "Removing test artifacts..."
rm -f tests/bio_write_test.txt 2>/dev/null || true
rm -f tests/*.tmp 2>/dev/null || true
rm -f wolfcrypt/benchmark/*.info 2>/dev/null || true
find . -name "*.stdout" -delete 2>/dev/null || true
find . -name "*.stderr" -delete 2>/dev/null || true
find . -name ".dirstamp" -delete 2>/dev/null || true

# Remove certificate artifacts (not the test certs in certs/ directory)
echo "Removing certificate artifacts..."
rm -f certeccrsa.der certeccrsa.pem 2>/dev/null || true
rm -f ecc-key.pem 2>/dev/null || true
rm -f test-write-dhparams.pem 2>/dev/null || true

# Remove packaging artifacts
echo "Removing packaging artifacts..."
rm -f rpm/spec 2>/dev/null || true
rm -f wolfssl-*.tar.gz 2>/dev/null || true

# Remove coverage files
echo "Removing coverage files..."
find . -name "*.gcda" -delete 2>/dev/null || true
find . -name "*.gcno" -delete 2>/dev/null || true
find . -name "*.gcov" -delete 2>/dev/null || true
find . -name "*.profdata" -delete 2>/dev/null || true

# Remove editor backup files
echo "Removing editor backup files..."
find . -name "*~" -delete 2>/dev/null || true
find . -name "*.bak" -delete 2>/dev/null || true
find . -name "*.orig" -delete 2>/dev/null || true

# Remove log files
echo "Removing log files..."
rm -f out*.log test.log 2>/dev/null || true

# Remove autom4te cache
echo "Removing autom4te cache..."
rm -rf autom4te.cache 2>/dev/null || true

# Ensure debian/control exists
echo "Ensuring debian/control exists..."
if [ ! -f "debian/control" ] && [ -f "debian/control.in" ]; then
    cp debian/control.in debian/control
fi

# Make sure debian/rules is executable
echo "Setting debian/rules permissions..."
chmod +x debian/rules 2>/dev/null || true

echo "Cleanup completed successfully!"
echo ""
echo "Source tree is now clean and ready for packaging."
echo "You can now run:"
echo "  ./debian/create-orig-tarball.sh"
echo "  dpkg-buildpackage -S -us -uc"
