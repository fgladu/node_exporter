#!/bin/bash

# Fonction pour obtenir la version installée
get_installed_version() {
	/usr/local/bin/node_exporter --version 2>/dev/null | grep -oP 'version \K(.*?)(?=\s)'
}

# Récupérer la dernière version en utilisant l'API GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')

# Sortir si la dernière version n'a pas pu être récupérée
if [ -z "$LATEST_VERSION" ]; then
	echo "Échec de récupération de la dernière version depuis l'API GitHub."
	exit 1
fi

# Définir la version téléchargée comme la dernière version sans le "v"
VERSION="${LATEST_VERSION#v}"

# Vérifier la version actuellement installée
INSTALLED_VERSION=$(get_installed_version)

# Comparer la version GitHub avec la version installée
if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
	echo "Rien à faire! node_exporter est déjà à jour (version $INSTALLED_VERSION) sur $(hostname). Opération terminée."
	exit 0
fi

echo "Mise à jour de node_exporter de la version $INSTALLED_VERSION à la version $VERSION sur $(hostname)."

# Télécharger et installer la dernière version
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"

# Télécharger la dernière version
if ! wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz"; then
	echo "Échec de téléchargement de la dernière version."
	exit 1
fi

# Extraire le tarball
if ! tar xvfz "$BINARY_NAME.tar.gz"; then
	echo "Échec d'extraction du tarball."
	exit 1
fi

# Remplacer l'ancien binaire
if ! sudo mv "$BINARY_NAME/node_exporter" /usr/local/bin/; then
	echo "Échec de remplacement du binaire."
	exit 1
fi

# Définir les autorisations
if ! sudo chown root:root /usr/local/bin/node_exporter && sudo chmod +x /usr/local/bin/node_exporter; then
	echo "Échec de définition des autorisations."
	exit 1
fi

# Nettoyer les fichiers extraits
rm -rf "$BINARY_NAME.tar.gz" "$BINARY_NAME"

# Redémarrer le service node_exporter
if ! sudo systemctl restart node_exporter; then
	echo "Échec de redémarrage du service node_exporter."
	exit 1
fi

# Vérifier la mise à jour
if [ "$(get_installed_version)" == "$VERSION" ]; then
	echo "Service mis à jour et démarré avec succès."

	# Envoyer une notification en utilisant le webhook de Telegram
	TOKEN="VOTRE_TOKEN_TELEGRAM"
	CHAT_ID="VOTRE_CHAT_ID"
	MESSAGE="node_exporter mis à jour à la version $VERSION sur $(hostname)."
	IMAGE_URL="https://res.cloudinary.com/fgladu/image/upload/v1713967592/perm/node_exporter_logo.png"
	ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
	URL="https://api.telegram.org/bot$TOKEN/sendPhoto"
	
	JSON_PAYLOAD="{\"chat_id\":\"$CHAT_ID\",\"caption\":\"$ESCAPED_MESSAGE\",\"photo\":\"$IMAGE_URL\"}"
	
	curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$URL"

	# Sortir avec succès
	exit 0
else
	echo "Échec de la mise à jour du service. Sortie."

	# Envoyer une notification en utilisant le webhook de Telegram
	TOKEN="VOTRE_TOKEN_TELEGRAM"
	CHAT_ID="VOTRE_CHAT_ID"
	MESSAGE="Échec de la mise à jour de node_exporter sur $(hostname)."
	IMAGE_URL="https://res.cloudinary.com/fgladu/image/upload/v1713967592/perm/node_exporter_logo.png"
	ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
	URL="https://api.telegram.org/bot$TOKEN/sendPhoto"
	
	JSON_PAYLOAD="{\"chat_id\":\"$CHAT_ID\",\"caption\":\"$ESCAPED_MESSAGE\",\"photo\":\"$IMAGE_URL\"}"
	
	curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$URL"

	# Sortir avec un code d'erreur
	exit 1
fi
