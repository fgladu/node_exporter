#!/bin/bash

# Set the path to the log file
LOG_FILE="/var/log/node_exporter_update.log"

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

# Check if the installation is needed
if [ -z "$INSTALLED_VERSION" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Installing node_exporter." >> "$LOG_FILE"
    
    # Uncomment and replace the line below with your actual installation command
    # For example, you might use: apt-get install -y node-exporter
    # or any other installation method depending on your system
    # For now, let's assume it's installing from a custom binary
    # cp /path/to/custom/node_exporter /usr/local/bin/
    
    # Uncomment and replace the line below with your actual installation command
    # cp /path/to/custom/node_exporter /usr/local/bin/
    
    # Attempt to determine the installed version again
    INSTALLED_VERSION=$(get_installed_version)

    # If still unable to determine the installed version, exit with an error
    if [ -z "$INSTALLED_VERSION" ]; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to determine the currently installed version after installation." >> "$LOG_FILE"
        exit 1
    fi
fi

# Fetch the latest version using GitHub API
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')

# Exit if the latest version couldn't be fetched
if [ -z "$LATEST_VERSION" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to fetch the latest version from GitHub API." >> "$LOG_FILE"
    exit 1
fi

# Set the downloaded version to the latest version without the "v"
VERSION="${LATEST_VERSION#v}"

# Compare the GitHub version with the installed version
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - node_exporter is already up-to-date (version $INSTALLED_VERSION)." >> "$LOG_FILE"
    exit 0
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - Updating node_exporter from version $INSTALLED_VERSION to version $VERSION." >> "$LOG_FILE"

# Stop the node_exporter service
echo "$(date +"%Y-%m-%d %H:%M:%S") - Stopping the node_exporter service." >> "$LOG_FILE"
systemctl stop node_exporter >> "$LOG_FILE" 2>&1

# Replace the old binary with the new one
echo "$(date +"%Y-%m-%d %H:%M:%S") - Copying the new node_exporter binary to /usr/local/bin/." >> "$LOG_FILE"
# Uncomment and replace the line below with your actual installation command
# cp /path/to/new/node_exporter /usr/local/bin/

# Start the node_exporter service
echo "$(date +"%Y-%m-%d %H:%M:%S") - Starting the node_exporter service." >> "$LOG_FILE"
systemctl start node_exporter >> "$LOG_FILE" 2>&1

# Sleep to allow the service to start
sleep 5

# Check the status of the service
STATUS_OUTPUT=$(systemctl status node_exporter 2>&1)

# Check if the service is active
if [[ $STATUS_OUTPUT =~ "Active: active" ]]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Service updated and started successfully." >> "$LOG_FILE"

    # Send notification using webhook only if an update was performed
    url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=YOUR_API_KEY&token=YOUR_TOKEN"
    curl -X POST -H "Content-Type: application/json" -d '{"text": "node_exporter updated to version '"$VERSION"'."}' "$url_webhook" >> "$LOG_FILE" 2>&1

    # Exit with success
    exit 0
else
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to start the updated service." >> "$LOG_FILE"

    # Send notification using webhook if the update failed
    url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=YOUR_API_KEY&token=YOUR_TOKEN"
    curl -X POST -H "Content-Type: application/json" -d '{"text": "Failed to start node_exporter service after the update."}' "$url_webhook" >> "$LOG_FILE" 2>&1

    # Exit with an error code
    exit 1
fi

# 10:23
