#!/bin/bash

set -e

echo "======================================"
echo "🐝 HiveSense Automated Installer"
echo "======================================"

# -----------------------------
# Configuration
# -----------------------------
REPO_URL="https://github.com/<YOUR_USERNAME>/hivesense.git"
INSTALL_DIR="$HOME/hivesense"

# -----------------------------
# System Update
# -----------------------------
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# -----------------------------
# Install Required Packages
# -----------------------------
echo "Installing dependencies..."
sudo apt install -y \
    curl \
    git \
    ufw \
    unattended-upgrades \
    ca-certificates \
    openssl

# -----------------------------
# Install Docker
# -----------------------------
if ! command -v docker &> /dev/null
then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker already installed."
fi

sudo apt install -y docker-compose-plugin

# -----------------------------
# Configure Firewall
# -----------------------------
echo "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22      # SSH
sudo ufw allow 8123    # Home Assistant
sudo ufw allow 1883    # MQTT
sudo ufw --force enable

# -----------------------------
# Enable Automatic Updates
# -----------------------------
echo "Enabling unattended upgrades..."
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# -----------------------------
# Clone or Update Repo
# -----------------------------
if [ -d "$INSTALL_DIR" ]; then
    echo "HiveSense already exists. Pulling latest..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning HiveSense repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# -----------------------------
# Ensure Directory Structure
# -----------------------------
echo "Ensuring required directories exist..."
mkdir -p mosquitto/config
mkdir -p mosquitto/data
mkdir -p mosquitto/log
mkdir -p homeassistant/www/community

# -----------------------------
# Install auto-entities
# -----------------------------
if [ ! -d "homeassistant/www/community/auto-entities" ]; then
    echo "Installing auto-entities..."
    git clone https://github.com/thomasloven/lovelace-auto-entities.git \
        homeassistant/www/community/auto-entities
else
    echo "auto-entities already installed."
fi

# -----------------------------
# Install fold-entity-row
# -----------------------------
if [ ! -d "homeassistant/www/community/fold-entity-row" ]; then
    echo "Installing fold-entity-row..."
    git clone https://github.com/thomasloven/lovelace-fold-entity-row.git \
        homeassistant/www/community/fold-entity-row
else
    echo "fold-entity-row already installed."
fi

# -----------------------------
# Ensure Lovelace Resources
# -----------------------------
LOVELACE_FILE="homeassistant/ui-lovelace.yaml"

if [ -f "$LOVELACE_FILE" ]; then
    echo "Verifying Lovelace resources..."

    if ! grep -q "auto-entities.js" "$LOVELACE_FILE"; then
        sed -i '1s;^;resources:\n  - url: /local/community/auto-entities/auto-entities.js\n    type: module\n  - url: /local/community/fold-entity-row/fold-entity-row.js\n    type: module\n\n;' "$LOVELACE_FILE"
        echo "Lovelace resources added."
    else
        echo "Lovelace resources already present."
    fi
else
    echo "ui-lovelace.yaml not found!"
fi

# -----------------------------
# Create .env if Missing
# -----------------------------
if [ ! -f ".env" ]; then
    echo "Creating .env from .env.example"
    cp .env.example .env
    echo ""
    echo "IMPORTANT:"
    echo "Please edit the .env file before continuing if needed."
    echo ""
fi

# -----------------------------
# Launch Containers
# -----------------------------
echo "Starting HiveSense containers..."
docker compose pull
docker compose up -d

echo ""
echo "======================================"
echo "HiveSense Setup Complete!"
echo "======================================"
echo "Home Assistant:"
echo "   http://$(hostname -I | awk '{print $1}'):8123"
echo ""
echo "MQTT Broker running on port 1883"
echo ""
echo "First boot may take ~1 minute."
echo "Open Home Assistant in browser and complete onboarding."
echo ""
echo "🐝 Your hive monitoring system is ready."
echo "======================================"
