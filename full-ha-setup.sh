#!/bin/bash
set -e

# Configuration
CONFIG_PATH="/opt/homeassistant/config"
HACS_VERSION="1.32.0"
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📁 Using Home Assistant config directory: $CONFIG_PATH"

# ------------------------------------------------------------------------------
# Install required packages
# ------------------------------------------------------------------------------
echo "📦 Installing required packages..."
apt update
apt install -y ca-certificates curl gnupg lsb-release git unzip net-tools

# ------------------------------------------------------------------------------
# Install Docker if missing
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo "🐳 Installing Docker..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "✅ Docker is already installed."
fi

# ------------------------------------------------------------------------------
# Create config path
# ------------------------------------------------------------------------------
echo "📁 Preparing Home Assistant config directory..."
mkdir -p "$CONFIG_PATH/custom_components"

# ------------------------------------------------------------------------------
# Pull Docker images
# ------------------------------------------------------------------------------
echo "⬇️ Pulling Docker images..."
docker pull portainer/portainer-ce:latest
docker pull filebrowser/filebrowser:latest
docker pull homeassistant/home-assistant:stable

# ------------------------------------------------------------------------------
# Run containers
# ------------------------------------------------------------------------------
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
# Install HACS
# ------------------------------------------------------------------------------
echo "⬇️ Installing HACS v$HACS_VERSION..."
cd "$CONFIG_PATH/custom_components"
rm -rf hacs
mkdir -p hacs
cd hacs

curl -sfSL "https://github.com/hacs/integration/releases/download/$HACS_VERSION/hacs.zip" -o hacs.zip

# Validate ZIP contents
unzip -l hacs.zip | grep -q __init__.py || {
    echo "❌ hacs.zip is invalid or missing files."
    exit 1
}

unzip -q hacs.zip
rm hacs.zip

# ------------------------------------------------------------------------------
# Remove deprecated YAML line if exists
# ------------------------------------------------------------------------------
CONFIG_FILE="$CONFIG_PATH/configuration.yaml"
if grep -q "^hacs:" "$CONFIG_FILE"; then
    echo "🧹 Removing deprecated 'hacs:' YAML block..."
    sed -i '/^hacs:/d' "$CONFIG_FILE"
fi

# ------------------------------------------------------------------------------
# Setup /etc/issue banner
# ------------------------------------------------------------------------------
echo "🖥️ Setting up login banner..."

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
Description=Update /etc/issue with system info
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
echo -e "\n✅ Setup complete!"
echo "➡️ Access your services:"
echo "   🔧 Portainer:       https://$HOST_IP:9443"
echo "   📁 FileBrowser:     http://$HOST_IP:8080"
echo "   🏠 Home Assistant:  http://$HOST_IP:8123"
echo "📦 HACS installed at: $CONFIG_PATH/custom_components/hacs"
echo "💡 Login screen updated with IP & system info."
