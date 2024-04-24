#!/bin/bash

# Telegram Bot settings
TELEGRAM_BOT_TOKEN="6273600508:AAH658m8FSuZXqPMhJ2jWSUZto0sYX33x5I"
TELEGRAM_CHAT_ID="5028848599"

# Fonction pour obtenir la version installée
get_installed_version() {
	/usr/local/bin/node_exporter --version 2>/dev/null | grep -oP 'version \K(.*?)(?=\s)'
}

# Récupérer la dernière version en utilisant l'API GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')

# Sortir si la dernière version n'a pas pu être récupérée
if [ -z "$LATEST_VERSION" ]; then
	echo "Échec de récupération de la dernière version depuis l'API GitHub."
	send_notification "Échec de récupération de la dernière version depuis l'API GitHub."
	exit 1
fi

# Définir la version téléchargée comme la dernière version sans le "v"
VERSION="${LATEST_VERSION#v}"

# Vérifier la version actuellement installée
INSTALLED_VERSION=$(get_installed_version)

# Comparer la version GitHub avec la version installée
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
	echo "node_exporter est déjà à jour (version $INSTALLED_VERSION) sur $(hostname). Opération terminée."
	send_notification "node_exporter est déjà à jour (version $INSTALLED_VERSION) sur $(hostname)."
	exit 0
fi

echo "Mise à jour de node_exporter de la version $INSTALLED_VERSION à la version $VERSION sur $(hostname)."

# Télécharger et installer la dernière version
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"

# Télécharger la dernière version
if ! wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz"; then
	echo "Échec de téléchargement de la dernière version."
	send_notification "Échec de téléchargement de la dernière version."
	exit 1
fi

# Extraire le tarball
if ! tar xvfz "$BINARY_NAME.tar.gz"; then
	echo "Échec d'extraction du tarball."
	send_notification "Échec d'extraction du tarball."
	exit 1
fi

# Remplacer l'ancien binaire
if ! sudo mv "$BINARY_NAME/node_exporter" /usr/local/bin/; then
	echo "Échec de remplacement du binaire."
	send_notification "Échec de remplacement du binaire."
	exit 1
fi

# Définir les autorisations
if ! sudo chown root:root /usr/local/bin/node_exporter && sudo chmod +x /usr/local/bin/node_exporter; then
	echo "Échec de définition des autorisations."
	send_notification "Échec de définition des autorisations."
	exit 1
fi

# Nettoyer les fichiers extraits
rm -rf "$BINARY_NAME.tar.gz" "$BINARY_NAME"

# Redémarrer le service node_exporter
if ! sudo systemctl restart node_exporter; then
	echo "Échec de redémarrage du service node_exporter."
	send_notification "Échec de redémarrage du service node_exporter."
	exit 1
fi

# Notification message
message="node_exporter mis à jour de $INSTALLED_VERSION à $VERSION sur $(hostname)."
photo_url="https://res.cloudinary.com/fgladu/image/upload/v1713967592/perm/node_exporter_logo.png"

# Send a photo using curl with a caption
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendPhoto" \
			 -F "chat_id=$TELEGRAM_CHAT_ID" \
			 -F "caption=$message" \
			 -F "photo=$photo_url"

# Vérifier la mise à jour
if [ "$(get_installed_version)" == "$VERSION" ]; then
	echo "Service mis à jour et démarré avec succès."
	exit 0
else
	echo "Échec de la mise à jour du service. Sortie."
	send_notification "Échec de la mise à jour du service."
	exit 1
fi

# Fonction pour envoyer une notification Telegram
send_notification() {
	local message="$1"
	curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
			 -d "chat_id=$TELEGRAM_CHAT_ID" \
			 -d "text=$message"
}
# 10:59
