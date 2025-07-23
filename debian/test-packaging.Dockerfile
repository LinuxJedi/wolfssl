FROM debian:bookworm

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    debhelper \
    devscripts \
    fakeroot \
    dpkg-dev \
    autotools-dev \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source code
COPY . /build/

# Make sure we have the right permissions
RUN chmod +x debian/rules debian/create-orig-tarball.sh debian/create-source-package.sh debian/prepare-build.sh debian/clean-for-packaging.sh debian/build-source-package.sh

# Build source package using robust synchronized approach
RUN ./debian/build-source-package.sh

# Generate configure script for binary build
RUN if [ ! -f configure ]; then ./autogen.sh; fi

# Build binary packages from source
RUN dpkg-buildpackage -b -us -uc

# Install and test the packages
RUN dpkg -i ../libwolfssl*.deb || apt-get install -f -y

# List generated files
RUN ls -la ../*.dsc ../*.tar.* ../*.changes || true

# Run a basic test to verify installation
RUN pkg-config --exists wolfssl && echo "wolfSSL pkg-config found" || echo "wolfSSL pkg-config NOT found"
RUN ldconfig -p | grep wolfssl && echo "wolfSSL library found in ldconfig" || echo "wolfSSL library NOT found"
RUN test -f /usr/include/wolfssl/ssl.h && echo "wolfSSL headers installed" || echo "wolfSSL headers NOT installed"

# Collect all artifacts in a single directory for easy extraction
RUN mkdir -p /artifacts && \
    cp ../*.deb /artifacts/ 2>/dev/null || true && \
    cp ../*.dsc /artifacts/ 2>/dev/null || true && \
    cp ../*.tar.* /artifacts/ 2>/dev/null || true && \
    cp ../*.changes /artifacts/ 2>/dev/null || true && \
    cp ../*.buildinfo /artifacts/ 2>/dev/null || true && \
    ls -la /artifacts/

CMD ["echo", "wolfSSL source and binary packaging test completed"]
