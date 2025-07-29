#!/bin/bash

# Detect Home Assistant config path
HA_CONFIG_DIR="/home/homeassistant"  # Change if your config is elsewhere
HACS_DIR="$HA_CONFIG_DIR/custom_components/hacs"

echo "🔍 Checking dependencies..."
apt update && apt install -y git curl unzip

# Make sure we're in the config directory
cd "$HA_CONFIG_DIR" || { echo "❌ Cannot find config dir"; exit 1; }

echo "📁 Creating custom_components directory if needed..."
mkdir -p custom_components

echo "⬇️ Downloading HACS..."
curl -sfSL https://github.com/hacs/integration/releases/latest/download/hacs.zip -o hacs.zip

echo "📦 Unpacking HACS..."
unzip -q hacs.zip -d custom_components
rm hacs.zip

echo "✅ HACS files placed in: $HACS_DIR"

echo "📄 Verifying Home Assistant config contains HACS setup..."

CONFIG_YAML="$HA_CONFIG_DIR/configuration.yaml"
if ! grep -q "hacs:" "$CONFIG_YAML"; then
  echo -e "\n✅ Adding 'hacs:' entry to configuration.yaml"
  echo -e "\n# HACS integration\nhacs:" >> "$CONFIG_YAML"
else
  echo "✔️ 'hacs:' already in configuration.yaml"
fi

echo "🔁 Restart Home Assistant to load HACS."
echo "➡️ Then go to: Settings → Devices & Services → + Add Integration → Search 'HACS'"
