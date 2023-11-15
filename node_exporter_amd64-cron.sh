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

# Exit if unable to determine the installed version
if [ -z "$INSTALLED_VERSION" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to determine the currently installed version." >> "$LOG_FILE"
    exit 1
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

# Attempt to restart the service up to 3 times
for i in {1..3}; do
    # Start and enable the node_exporter service
    systemctl enable --now node_exporter >> "$LOG_FILE" 2>&1
    sleep 5  # Adjust this sleep time as needed

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
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to start service (Attempt $i)." >> "$LOG_FILE"
    fi
done

# Send notification using webhook if all attempts failed
url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=YOUR_API_KEY&token=YOUR_TOKEN"
curl -X POST -H "Content-Type: application/json" -d '{"text": "Failed to start node_exporter service after 3 attempts."}' "$url_webhook" >> "$LOG_FILE" 2>&1

# Exit with an error code
exit 1

# 19:16
