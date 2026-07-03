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
    # Locale support (critical: fixes perl/bash setlocale warnings)
    locales \
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

# Generate en_US.UTF-8 locale at build time and set it as system default
RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Bake locale environment variables into the image (persists across every shell/exec)
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Verify installed versions
RUN g++ --version && \
    cmake --version && \
    perl --version && \
    git --version && \
    locale

# Set up working directory
WORKDIR /workspace

# Set environment variables for Pythia
ENV PYTHIA_HOME=/workspace

# Default shell
SHELL ["/bin/bash", "-c"]

# Reset frontend
ENV DEBIAN_FRONTEND=
