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

# Check the currently installed version
INSTALLED_VERSION=$(node_exporter --version 2>/dev/null | grep -oP 'version \K(.*?)(?=\s)')

# Compare the installed version with the latest version
if [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" != "$VERSION" ]; then
    echo "Updating node_exporter to version $VERSION."

    # Stop the running node_exporter service
    sudo systemctl stop node_exporter > /dev/null 2>&1

    # Download the latest version
    DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
    BINARY_NAME="node_exporter-$VERSION.linux-amd64"
    wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz" > /dev/null 2>&1
    tar xvfz "$BINARY_NAME.tar.gz" > /dev/null 2>&1
    sudo mv "$BINARY_NAME/node_exporter" /usr/local/bin/ > /dev/null 2>&1

    # Set permissions
    sudo chown root:root /usr/local/bin/node_exporter > /dev/null 2>&1
    sudo chmod +x /usr/local/bin/node_exporter > /dev/null 2>&1

    # Cleanup extracted files
    rm -rf "$BINARY_NAME.tar.gz" "$BINARY_NAME"

    # Reload the daemon config files
    sudo systemctl daemon-reload > /dev/null 2>&1

    # Attempt to restart the service up to 3 times
    for i in {1..3}; do
        # Start and enable the node_exporter service
        sudo systemctl enable --now node_exporter > /dev/null 2>&1
        sleep 5  # Adjust this sleep time as needed

        # Check the status of the service
        STATUS_OUTPUT=$(sudo systemctl status node_exporter 2>&1)

        # Check if the service is active
        if [[ $STATUS_OUTPUT =~ "Active: active" ]]; then
            echo "Service updated and started successfully."
            exit 0
        else
            echo "Failed to start service (Attempt $i)."
        fi
    done

    # Send notification using webhook
    url_webhook="https://chat.googleapis.com/v1/spaces/AAAAc6zAGns/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=7BjA6cigOrHq1AJpopqcCSRn06aE-wJwVSUhE3xcy2W"
    curl -X POST -H "Content-Type: application/json" -d '{"text": "Failed to start node_exporter service after 3 attempts."}' "$url_webhook"

    # Exit with an error code
    exit 1
else
    echo "node_exporter is already up-to-date (version $INSTALLED_VERSION)."
fi

# Version 2023-11-14_16:26:30
