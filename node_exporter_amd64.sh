#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root." 1>&2
	exit 1
fi

# Fetch the latest version using GitHub API
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')

# Exit if the latest version couldn't be fetched
if [ -z "$LATEST_VERSION" ]; then
	echo "Failed to fetch the latest version from GitHub API."
	exit 1
fi

# Set the downloaded version to the latest version without the "v"
VERSION="${LATEST_VERSION#v}"

# Rest of the script remains the same...
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"

# Create the node_exporter.service file if it doesn't exist
if [ ! -f "$SERVICE_FILE" ]; then
	echo "[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target" | sudo tee "$SERVICE_FILE" > /dev/null
fi

# Create the node_exporter user if it doesn't exist
id -u nodeusr &>/dev/null || sudo useradd -rs /bin/false nodeusr

# Stop the running node_exporter service
sudo systemctl stop node_exporter

# Download the latest version
wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz"

# Extract the tarball
tar xvfz "$BINARY_NAME.tar.gz"

# Replace the old binary
sudo mv "$BINARY_NAME/node_exporter" /usr/local/bin/

# Set permissions
sudo chown root:root /usr/local/bin/node_exporter
sudo chmod +x /usr/local/bin/node_exporter

# Cleanup extracted files
rm -rf "$BINARY_NAME.tar.gz" "$BINARY_NAME"

# Reload the daemon config files
sudo systemctl daemon-reload

# Start and enable the node_exporter service
sudo systemctl enable --now node_exporter

# Verify the update
sudo systemctl status node_exporter
