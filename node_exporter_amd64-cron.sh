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

# ... (unchanged)

# Stop the running node_exporter service
sudo systemctl stop node_exporter

# Attempt to restart the service up to 3 times
for i in {1..3}; do
	# Start and enable the node_exporter service
	sudo systemctl enable --now node_exporter
	sleep 5  # Adjust this sleep time as needed

	# Check the status of the service
	sudo systemctl status node_exporter > status_output.txt 2>&1

	# Check if the service is active
	if grep -q "Active: active" status_output.txt; then
		echo "Service started successfully."
		rm status_output.txt  # Cleanup the temporary file
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
