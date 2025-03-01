FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl wget git pkg-config build-essential libudev-dev libssl-dev jq bc

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Solana CLI tools
RUN sh -c "$(curl -sSfL https://release.solana.com/v1.16.0/install)" \
    && export PATH="/root/.local/share/solana/install/active_release/bin:$PATH" \
    && echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> /root/.bashrc

# Install Anchor
RUN cargo install --git https://github.com/coral-xyz/anchor avm --locked --force \
    && avm install latest \
    && avm use latest

# Install SPL Token CLI
RUN cargo install spl-token-cli

# Set up a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set the default user
USER $USERNAME
WORKDIR /home/$USERNAME

# Copy Solana installation to user directory
RUN mkdir -p /home/$USERNAME/.local/share/solana/ \
    && cp -r /root/.local/share/solana/install /home/$USERNAME/.local/share/solana/ \
    && echo 'export PATH="/home/'$USERNAME'/.local/share/solana/install/active_release/bin:$PATH"' >> /home/$USERNAME/.bashrc

# Install Rust for the user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source $HOME/.cargo/env' >> /home/$USERNAME/.bashrc

# Configure Solana for devnet
RUN mkdir -p /home/$USERNAME/.config/solana \
    && echo 'export PATH="/home/'$USERNAME'/.local/share/solana/install/active_release/bin:$PATH"' >> /home/$USERNAME/.bashrc \
    && export PATH="/home/$USERNAME/.local/share/solana/install/active_release/bin:$PATH" \
    && solana config set --url https://api.devnet.solana.com
