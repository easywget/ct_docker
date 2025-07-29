#!/bin/bash

set -e

echo " ^=^t^m Detecting system info..."
source /etc/os-release
OS_ID=$ID
OS_CODENAME=$VERSION_CODENAME
ARCH=$(dpkg --print-architecture)
HOST_IP=$(hostname -I | awk '{print $1}')
echo " ^=^v   ^o  Detected: $OS_ID $OS_CODENAME ($ARCH)"
echo " ^=^s  IP Address: $HOST_IP"

# ------------------------------------------------------------------------------
# INSTALL DOCKER
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo " ^=^s  Installing Docker..."
    apt update
    apt install -y ca-certificates curl gnupg lsb-release

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$OS_ID $OS_CODENAME stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
else
    echo " ^|^e Docker is already installed."
fi

# ------------------------------------------------------------------------------
# PULL IMAGES
# ------------------------------------------------------------------------------
echo " ^=^p  Pulling images..."
docker pull portainer/portainer-ce:latest
docker pull filebrowser/filebrowser:latest
docker pull homeassistant/home-assistant:stable

# ------------------------------------------------------------------------------
# START PORTAINER
# ------------------------------------------------------------------------------
if [ ! "$(docker ps -a -q -f name=portainer)" ]; then
    echo " ^=^z^` Starting Portainer..."
    docker run -d \
        --name portainer \
        --restart=always \        --name portainer \
        --restart=always \
        -p 8000:8000 -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
else
    echo " ^z   ^o  Portainer already exists. Skipping."
fi

# ------------------------------------------------------------------------------
# START FILEBROWSER
# ------------------------------------------------------------------------------
if [ ! "$(docker ps -a -q -f name=filebrowser)" ]; then
    echo " ^=^s^a Starting FileBrowser..."
    docker run -d \
        --name filebrowser \
        --restart unless-stopped \
        -p 8080:80 \
        -v /:/srv \
        filebrowser/filebrowser:latest
else
    echo " ^z   ^o  FileBrowser already exists. Skipping."
fi

# ------------------------------------------------------------------------------
# START HOME ASSISTANT
# ------------------------------------------------------------------------------
if [ ! "$(docker ps -a -q -f name=homeassistant)" ]; then
    echo " ^=^o  Starting Home Assistant..."
    mkdir -p /home/homeassistant
    docker run -d \
        --name homeassistant \
        --privileged \
        --restart unless-stopped \
        --network host \
        -v /home/homeassistant:/config \
        -e TZ=Europe/London \
        homeassistant/home-assistant:stable
else
    echo " ^z   ^o  Home Assistant already exists. Skipping."
fi

# ------------------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------------------
echo -e "\n ^|^e All done. Access your services:"
echo " ^=^t  Portainer:      https://$HOST_IP:9443"
echo " ^=^s^a FileBrowser:    http://$HOST_IP:8080"
echo " ^=^o  Home Assistant: http://$HOST_IP:8123"
