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
	echo "node_exporter is already up-to-date (version $INSTALLED_VERSION). Exiting."
	exit 0
fi

echo "Updating node_exporter from version $INSTALLED_VERSION to version $VERSION."

# Attempt to restart the service up to 3 times
for i in {1..3}; do
	# Start and enable the node_exporter service
	systemctl enable --now node_exporter > /dev/null 2>&1
	sleep 5  # Adjust this sleep time as needed

	# Check the status of the service
	STATUS_OUTPUT=$(systemctl status node_exporter 2>&1)

	# Check if the service is active
	if [[ $STATUS_OUTPUT =~ "Active: active" ]]; then
		echo "Service updated and started successfully."

		# Send notification using webhook only if an update was performed
		url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
		curl -X POST -H "Content-Type: application/json" -d '{"text": "node_exporter updated to version '"$VERSION"'."}' "$url_webhook"

		# Exit with success
		exit 0
	else
		echo "Failed to start service (Attempt $i)."
	fi
done

# Send notification using webhook if all attempts failed
url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
curl -X POST -H "Content-Type: application/json" -d '{"text": "Failed to start node_exporter service after 3 attempts."}' "$url_webhook"

# Exit with an error code
exit 1

# 10:25
