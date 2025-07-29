#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# DETECT HOME ASSISTANT CONFIG PATH FROM DOCKER
# ------------------------------------------------------------------------------
CONFIG_PATH=$(docker inspect homeassistant | grep '"Source":' | grep -i config | head -n1 | cut -d '"' -f4)
if [ -z "$CONFIG_PATH" ]; then
    echo "❌ Unable to detect Home Assistant config path from Docker volume mount."
    exit 1
fi

echo "📁 Detected Home Assistant config directory: $CONFIG_PATH"
mkdir -p "$CONFIG_PATH/custom_components"

# ------------------------------------------------------------------------------
# INSTALL DEPENDENCIES
# ------------------------------------------------------------------------------
echo "📦 Installing dependencies..."
apt update
apt install -y ca-certificates curl gnupg lsb-release git unzip net-tools

# ------------------------------------------------------------------------------
# INSTALL DOCKER (SKIPPED IF INSTALLED)
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo "🐳 Installing Docker..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
else
    echo "✅ Docker is already installed."
fi

# ------------------------------------------------------------------------------
# PULL & RUN CONTAINERS
# ------------------------------------------------------------------------------
echo "⬇️ Pulling images..."
docker pull portainer/portainer-ce:latest
docker pull filebrowser/filebrowser:latest
docker pull homeassistant/home-assistant:stable

# Portainer
if ! docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "🚀 Starting Portainer..."
    docker run -d \
        --name portainer \
        --restart=always \
        -p 8000:8000 -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
fi

# FileBrowser
if ! docker ps -a --format '{{.Names}}' | grep -q '^filebrowser$'; then
    echo "📁 Starting FileBrowser..."
    docker run -d \
        --name filebrowser \
        --restart unless-stopped \
        -p 8080:80 \
        -v /:/srv \
        filebrowser/filebrowser:latest
fi

# Home Assistant
if ! docker ps -a --format '{{.Names}}' | grep -q '^homeassistant$'; then
    echo "🏠 Starting Home Assistant..."
    docker run -d \
        --name homeassistant \
        --privileged \
        --restart unless-stopped \
        --network host \
        -v "$CONFIG_PATH":/config \
        -e TZ=Europe/London \
        homeassistant/home-assistant:stable
fi

# ------------------------------------------------------------------------------
# INSTALL HACS
# ------------------------------------------------------------------------------
echo "⬇️ Installing HACS to $CONFIG_PATH/custom_components/hacs"
cd "$CONFIG_PATH"
mkdir -p custom_components

curl -sfSL https://github.com/hacs/integration/releases/download/1.32.0/hacs.zip -o hacs.zip
unzip -q hacs.zip -d custom_components
rm hacs.zip

# Add HACS to config if missing
CONFIG_FILE="$CONFIG_PATH/configuration.yaml"
touch "$CONFIG_FILE"
if ! grep -q "hacs:" "$CONFIG_FILE"; then
    echo -e "\n# HACS\nhacs:" >> "$CONFIG_FILE"
fi

# ------------------------------------------------------------------------------
# SETUP DYNAMIC /etc/issue BANNER
# ------------------------------------------------------------------------------
echo "🖥️ Setting up dynamic /etc/issue..."

cat << 'EOF' > /usr/local/bin/update-issue.sh
#!/bin/bash
IP=$(hostname -I | awk '{print $1}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%
MEM=$(free -m | awk '/Mem:/ { printf("%.0f%%", $3/$2 * 100) }')

cat <<BANNER > /etc/issue
╔════════════════════════════════════════════╗
║        🏠 Smart Home Assistant Host        ║
╠════════════════════════════════════════════╣
║ 🖥️  IP Address:     $IP
║ 🔧 Portainer:       https://$IP:9443
║ 📁 FileBrowser:     http://$IP:8080
║ 🏠 Home Assistant:  http://$IP:8123
╠════════════════════════════════════════════╣
║ 📊 CPU Usage:       $CPU
║ 🧠 RAM Usage:       $MEM
╚════════════════════════════════════════════╝

Login:
BANNER
EOF

chmod +x /usr/local/bin/update-issue.sh

cat <<EOF > /etc/systemd/system/update-issue.service
[Unit]
Description=Update /etc/issue with dynamic banner
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-issue.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable update-issue.service
systemctl start update-issue.service

# ------------------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ All done!"
echo "➡️ Access your services at:"
echo "   🔧 Portainer:       https://$IP:9443"
echo "   📁 FileBrowser:     http://$IP:8080"
echo "   🏠 Home Assistant:  http://$IP:8123"
echo "💡 Login banner will auto-update on every boot."
