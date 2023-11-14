#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

# Function to get the installed version
get_installed_version() {
    /usr/local/bin/node_exporter --version 2>/dev/null | grep -oP 'version \K(.*?)(?=\s)'
}

# Check the currently installed version
INSTALLED_VERSION=$(get_installed_version)

# Exit if unable to determine the installed version
if [ -z "$INSTALLED_VERSION" ]; then
    echo "Failed to determine the currently installed version."
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

# Get the hostname
HOSTNAME=$(hostname)

# Print debug information
echo "Installed version on $HOSTNAME: $INSTALLED_VERSION"
echo "Latest version: $VERSION"

# Compare the GitHub version with the installed version
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
    echo "node_exporter on $HOSTNAME is already up-to-date (version $INSTALLED_VERSION). Exiting."
    exit 0
fi

echo "Updating node_exporter on $HOSTNAME from version $INSTALLED_VERSION to version $VERSION."

# Download the latest version
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"

# Stop the running node_exporter service
systemctl stop node_exporter

# Download and install the latest version
wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz"
tar xvfz "$BINARY_NAME.tar.gz" -C /usr/local/bin/ --strip-components=1
chmod +x /usr/local/bin/node_exporter
rm -f "$BINARY_NAME.tar.gz"

# Reload the daemon config files
systemctl daemon-reload

# Start the node_exporter service
systemctl start node_exporter

# Verify the update
systemctl status node_exporter

# Version 2023-11-14_18:25:00
