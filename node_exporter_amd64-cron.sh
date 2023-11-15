#!/bin/bash

# Function to get the installed version
get_installed_version() {
	/usr/local/bin/node_exporter --version 2>/dev/null | grep -oP 'version \K(.*?)(?=\s)'
}

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
INSTALLED_VERSION=$(get_installed_version)

# Get the hostname
HOSTNAME=$(hostname)

# Compare the GitHub version with the installed version
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
	echo "node_exporter is already up-to-date (version $INSTALLED_VERSION) on $HOSTNAME. Exiting."
	exit 0
fi

echo "Updating node_exporter from version $INSTALLED_VERSION to version $VERSION on $HOSTNAME."

# Uncomment and replace the line below with your actual installation command
# For example, you might use: apt-get install -y node-exporter
# or any other installation method depending on your system
# For now, let's assume it's installing from a custom binary
# cp /path/to/custom/node_exporter /usr/local/bin/

# Confirm the version after installation
NEW_INSTALLED_VERSION=$(get_installed_version)

# Send notification using webhook only if an update was performed
url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"

if [ "$NEW_INSTALLED_VERSION" == "$VERSION" ]; then
	echo "Service updated and started successfully."
	curl -X POST -H "Content-Type: application/json" -d '{"text": "node_exporter updated to version '"$VERSION"' on '"$HOSTNAME"'"."}' "$url_webhook"
	exit 0
else
	echo "Failed to update service. Exiting."
	curl -X POST -H "Content-Type: application/json" -d '{"text": "Failed to update node_exporter on '"$HOSTNAME"'."}' "$url_webhook"
	exit 1
fi

# 13:46
