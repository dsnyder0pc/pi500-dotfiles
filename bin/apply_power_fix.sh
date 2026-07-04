#!/bin/bash
set -e

# Ensure the script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo:"
  echo "sudo $0"
  exit 1
fi

echo "=== Raspberry Pi 5 Power Supply Fix for Argon ONE ==="

# 1. Update /boot/firmware/config.txt
CONFIG_FILE="/boot/firmware/config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
  # Fallback to older /boot/config.txt path if /boot/firmware/config.txt doesn't exist
  CONFIG_FILE="/boot/config.txt"
fi

echo "Target config file: $CONFIG_FILE"

# Backup config file
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Backup created at: $BACKUP_FILE"

# Check if usb_max_current_enable=1 is already in config.txt
if grep -q "usb_max_current_enable" "$CONFIG_FILE"; then
  echo "usb_max_current_enable is already present in $CONFIG_FILE. Verifying it is enabled..."
  # Replace any usb_max_current_enable=0 or similar with =1
  sed -i 's/^.*usb_max_current_enable.*/usb_max_current_enable=1/' "$CONFIG_FILE"
else
  echo "Appending usb_max_current_enable=1 to $CONFIG_FILE..."
  # Ensure it is placed under [all] if possible, or just append to end of file
  echo "usb_max_current_enable=1" >> "$CONFIG_FILE"
fi

# 2. Update EEPROM Bootloader Configuration
echo "Updating EEPROM Configuration..."

# Dump current EEPROM config
TEMP_CONF=$(mktemp /tmp/eeprom_XXXXXX.conf)
rpi-eeprom-config > "$TEMP_CONF"

# Modify EEPROM config:
# Remove usb_max_current_enable=1 if it is under the main EEPROM config (since it belongs in config.txt)
# Add PSU_MAX_CURRENT=5000 under [all] section if not present
sed -i '/usb_max_current_enable/d' "$TEMP_CONF"

if grep -q "PSU_MAX_CURRENT" "$TEMP_CONF"; then
  echo "PSU_MAX_CURRENT already exists in EEPROM. Updating value to 5000..."
  sed -i 's/^.*PSU_MAX_CURRENT.*/PSU_MAX_CURRENT=5000/' "$TEMP_CONF"
else
  echo "Adding PSU_MAX_CURRENT=5000 to EEPROM config..."
  # Append PSU_MAX_CURRENT=5000 after the [all] line
  if grep -q "^\[all\]" "$TEMP_CONF"; then
    sed -i '/^\[all\]/a PSU_MAX_CURRENT=5000' "$TEMP_CONF"
  else
    echo -e "\n[all]\nPSU_MAX_CURRENT=5000" >> "$TEMP_CONF"
  fi
fi

echo "New EEPROM configuration proposal:"
cat "$TEMP_CONF"
echo "----------------------------------"

# Apply the new configuration
rpi-eeprom-config --apply "$TEMP_CONF"

# Clean up temp file
rm -f "$TEMP_CONF"

echo "=== Success! ==="
echo "Please reboot your Raspberry Pi for these changes to take effect:"
echo "sudo reboot"
