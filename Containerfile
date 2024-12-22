# Use Rust image to build the binary
FROM rust:1.73 AS builder

# Set working directory
WORKDIR /app

# Copy workspace definition first
COPY Cargo.toml Cargo.lock ./

# Copy the workspace member directories (node, runtime)
COPY node ./node
COPY runtime ./runtime

# Copy additional workspace member directories if needed
COPY pallets ./pallets

# Ensure directories exist
RUN echo "Workspace structure:" && ls -la /app

# Install protoc and libclang-dev
RUN apt-get update && \
    apt-get install -y protobuf-compiler clang libclang-dev

# Set LIBCLANG_PATH environment variable
ENV LIBCLANG_PATH="/usr/lib/llvm-14/lib/libclang.so"

# Configure Git to use CLI for fetching
RUN git config --global url."https://".insteadOf git://

# Fetch dependencies
RUN cargo fetch

# Copy the full source code (optional for accuracy)
COPY . .

# Build the release binary
RUN cargo build --release

# Runtime stage with minimal image
FROM ubuntu:22.04 AS runtime

# Install tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add a non-root user
RUN useradd -m -u 1000 -U -s /bin/sh -d /netpulse netpulse && \
    mkdir -p /data /netpulse/.local/share && \
    chown -R netpulse:netpulse /data && \
    ln -s /data /netpulse/.local/share/netpulse

# Copy the binary
COPY --from=builder /app/target/release/Netpulse /usr/bin/Netpulse

# Set user
USER netpulse

# Expose ports
EXPOSE 9930 9333 9944 30333 30334

# Run the binary
CMD ["/usr/bin/Netpulse" , "--dev"]
