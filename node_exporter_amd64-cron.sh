#!/bin/bash

# Get the hostname
HOSTNAME=$(hostname)

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

# If unable to determine the installed version, treat it as older
if [ -z "$INSTALLED_VERSION" ]; then
	echo "Failed to determine the currently installed version. Treating it as older than online (version $VERSION)."
	INSTALLED_VERSION="0.0.0"
fi

# Compare the GitHub version with the installed version
if [ "$(printf '%s\n' "$VERSION" "$INSTALLED_VERSION" | sort -V | head -n1)" != "$INSTALLED_VERSION" ]; then
	echo "Local version $INSTALLED_VERSION is older than online version $VERSION."

	# Download and install the latest version
	DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/$LATEST_VERSION/node_exporter-$LATEST_VERSION.linux-amd64.tar.gz"
	DOWNLOAD_PATH="/tmp/node_exporter-$LATEST_VERSION.tar.gz"

	# Download the package
	curl -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL"

	# Extract the package
	tar -xzf "$DOWNLOAD_PATH" -C /tmp/

	# Move the binary to /usr/local/bin/
	mv "/tmp/node_exporter-$LATEST_VERSION.linux-amd64/node_exporter" /usr/local/bin/

	# Confirm the version
	CONFIRMED_VERSION=$(get_installed_version)
	echo "node_exporter updated to version $CONFIRMED_VERSION on $HOSTNAME."

	# Cleanup
	rm "$DOWNLOAD_PATH"
	rm -rf "/tmp/node_exporter-$LATEST_VERSION.linux-amd64/"

else
	echo "node_exporter is already up-to-date (version $INSTALLED_VERSION) on $HOSTNAME. Exiting."
	exit 0
fi

# Continue to the second part if local version is older than online
echo "Local version $INSTALLED_VERSION is older than online version $VERSION on $HOSTNAME."

# Attempt to restart the service up to 3 times
for i in {1..3}; do
	# Stop the node_exporter service
	systemctl stop node_exporter > /dev/null 2>&1
	sleep 10  # Adjust this sleep time as needed

	# Start the node_exporter service
	systemctl start node_exporter > /dev/null 2>&1
	sleep 10  # Adjust this sleep time as needed

	# Check the status of the service
	STATUS_OUTPUT=$(systemctl status node_exporter 2>&1)

	# Check if the service is active
	if [[ $STATUS_OUTPUT =~ "Active: active" ]]; then
		echo "Service updated and started successfully on $HOSTNAME."

		# Send notification using webhook only if an update was performed
		url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
		curl -X POST -H "Content-Type: application/json" -d '{"text": "'$HOSTNAME' - node_exporter updated to version '"$VERSION"'."}' "$url_webhook"

		# Exit with success
		exit 0
	else
		echo "Failed to start service (Attempt $i) on $HOSTNAME."
	fi
done

# Send notification using webhook if all attempts failed
url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
curl -X POST -H "Content-Type: application/json" -d '{"text": "'$HOSTNAME' - Failed to start node_exporter service after 3 attempts."}' "$url_webhook"

# Exit with an error code
exit 1

# 13:42
