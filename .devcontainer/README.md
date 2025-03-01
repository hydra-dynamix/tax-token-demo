# TaxAI Token Demo Development Container

This directory contains configuration files for setting up a development container for the TaxAI Token Demo project. This allows you to run the project in GitHub Codespaces or using Visual Studio Code's Remote - Containers extension.

## Files

- `devcontainer.json`: Main configuration file for the development container
- `Dockerfile`: Custom Docker image definition with all required dependencies
- `post-create.sh`: Script that runs after the container is created to set up the environment

## Features

The development container includes:

- Solana CLI tools (v1.16.0)
- Rust and Cargo
- Node.js 18
- SPL Token CLI
- Anchor framework
- Required VS Code extensions
- Automatic configuration for Solana devnet

## Getting Started

### GitHub Codespaces

1. Click on the "Code" button in your GitHub repository
2. Select the "Codespaces" tab
3. Click "Create codespace on main"

### VS Code Remote - Containers

1. Install the [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
2. Clone the repository to your local machine
3. Open the repository in VS Code
4. Click on the green button in the bottom-left corner of VS Code
5. Select "Reopen in Container"

## After Container Creation

Once the container is created and set up:

1. A new Solana keypair will be generated for you if one doesn't exist
2. The Solana CLI will be configured to use devnet
3. You can request an airdrop using `solana airdrop 2`
4. Run the demo: `./demo.sh`

## Customization

You can customize the development container by editing the files in this directory:

- Add additional VS Code extensions in `devcontainer.json`
- Install more packages in the `Dockerfile`
- Add setup steps to `post-create.sh`
