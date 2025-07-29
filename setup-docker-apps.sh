#!/bin/bash

set -e

echo "🔍 Detecting system info..."
source /etc/os-release
OS_ID=$ID
OS_CODENAME=$VERSION_CODENAME
ARCH=$(dpkg --print-architecture)
echo "Detected: $OS_ID $OS_CODENAME ($ARCH)"

echo "📦 Installing Docker if not present..."
if ! command -v docker &>/dev/null; then
    apt update
    apt install -y ca-certificates curl gnupg lsb-release

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $OS_CODENAME stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
else
    echo "✅ Docker already installed"
fi

echo "🐳 Pulling container images..."
docker pull portainer/portainer-ce:latest
docker pull filebrowser/filebrowser:latest
docker pull homeassistant/home-assistant:stable

echo "🚀 Running Portainer..."
docker run -d \
  --name portainer \
  --restart=always \
  -p 8000:8000 -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "📁 Running FileBrowser..."
docker run -d \
  --name filebrowser \
  --restart unless-stopped \
  -p 8080:80 \
  -v /:/srv \
  filebrowser/filebrowser:latest

echo "🏠 Running Home Assistant..."
mkdir -p /home/homeassistant  # ensure config directory exists

docker run -d \
  --name homeassistant \
  --privileged \
  --restart unless-stopped \
  --network=host \
  -v /home/homeassistant:/config \
  homeassistant/home-assistant:stable

HOST_IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ All containers are running!"
echo "👉 Portainer:       https://$HOST_IP:9443"
echo "👉 FileBrowser:     http://$HOST_IP:8080"
echo "👉 Home Assistant:  http://$HOST_IP:8123"

