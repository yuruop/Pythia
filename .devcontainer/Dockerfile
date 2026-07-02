# Pythia Dev Container Dockerfile
# Base: Ubuntu 22.04 with CUDA 12.x support for NVIDIA RTX 3090 GPUs

FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential build tools and Pythia dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    g++ \
    gcc \
    make \
    cmake \
    # Pythia-specific dependencies
    perl \
    # Utilities
    git \
    wget \
    curl \
    vim \
    nano \
    ca-certificates \
    openssh-client \
    # For trace download and verification
    libssl-dev \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify installed versions
RUN g++ --version && \
    cmake --version && \
    perl --version && \
    git --version

# Set up working directory
WORKDIR /workspace

# Set environment variables for Pythia
ENV PYTHIA_HOME=/workspace

# Default shell
SHELL ["/bin/bash", "-c"]

# Reset frontend
ENV DEBIAN_FRONTEND=
