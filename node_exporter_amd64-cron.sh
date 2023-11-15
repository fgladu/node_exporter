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
    echo "node_exporter est déjà à jour (version $INSTALLED_VERSION) sur $(hostname). Sortie."
    exit 0
fi

echo "Mise à jour de node_exporter de la version $INSTALLED_VERSION à la version $VERSION sur $(hostname)."

# Télécharger et installer la dernière version
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-amd64.tar.gz"
BINARY_NAME="node_exporter-$VERSION.linux-amd64"

# Télécharger la dernière version
wget "$DOWNLOAD_URL" -O "$BINARY_NAME.tar.gz"

# Extraire le tarball
tar xvfz "$BINARY_NAME.tar.gz"

# Remplacer l'ancien binaire
sudo mv "$BINARY_NAME/node_exporter" /usr/local/bin/

# Définir les autorisations
sudo chown root:root /usr/local/bin/node_exporter
sudo chmod +x /usr/local/bin/node_exporter

# Nettoyer les fichiers extraits
rm -rf "$BINARY_NAME.tar.gz" "$BINARY_NAME"

# Redémarrer le service node_exporter
sudo systemctl restart node_exporter

# Vérifier la mise à jour
if [ "$(get_installed_version)" == "$VERSION" ]; then
    echo "Service mis à jour et démarré avec succès."

    # Envoyer une notification en utilisant le webhook
    url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
    MESSAGE="$(hostname) - node_exporter mis à jour à la version $VERSION."
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
    JSON_PAYLOAD="{\"text\": \"$ESCAPED_MESSAGE\"}"
    curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$url_webhook"

    # Sortir avec succès
    exit 0
else
    echo "Échec de la mise à jour du service. Sortie."

    # Envoyer une notification en utilisant le webhook
    url_webhook="https://chat.googleapis.com/v1/spaces/AAAAhWiyzzE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=s0DeZk91_SvZdQAozzlhiCcgoKxmCu5nldP9TvlSbr4"
    MESSAGE="Échec de la mise à jour de node_exporter sur $(hostname)."
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
    JSON_PAYLOAD="{\"text\": \"$ESCAPED_MESSAGE\"}"
    curl -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$url_webhook"

    # Sortir avec un code d'erreur
    exit 1
fi

# 15:55
