#!/bin/bash

# Install script for development packages based on ~/.config/nvim/notes

echo "Installing development packages..."

# Update package list
sudo apt update

# Install packages via apt
sudo apt install -y \
    nodejs \
    npm \
    jq \
    nginx \
    direnv \
    ripgrep

# Install packages via snap
sudo snap install nvim --classic
sudo snap install gh
sudo snap install lazygit
sudo snap install bitwarden

echo "All packages installed successfully!"