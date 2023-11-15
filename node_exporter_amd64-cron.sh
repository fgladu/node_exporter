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

# Compare the GitHub version with the installed version
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
	echo "node_exporter is already up-to-date (version $INSTALLED_VERSION) on $(hostname). Exiting."
	exit 0
fi

echo "Updating node_exporter from version $INSTALLED_VERSION to version $VERSION on $(hostname)."

# Download and install the latest version
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"

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

# Restart the node_exporter service
sudo systemctl restart node_exporter

# Verify the update
if [ "$(get_installed_version)" == "$VERSION" ]; then
	echo "Service updated and started successfully."

	# Send notification using webhook
	url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
	MESSAGE="$(hostname) - node_exporter updated to version $VERSION."
	ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
	JSON_PAYLOAD="{\"text\": \"$ESCAPED_MESSAGE\"}"
	curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$url_webhook"

	# Exit with success
	exit 0
else
	echo "Failed to update service. Exiting."

	# Send notification using webhook
	url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
	MESSAGE="Failed to update node_exporter on $(hostname)."
	ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
	JSON_PAYLOAD="{\"text\": \"$ESCAPED_MESSAGE\"}"
	curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$url_webhook"

	# Exit with an error code
	exit 1
fi

# 14:11
