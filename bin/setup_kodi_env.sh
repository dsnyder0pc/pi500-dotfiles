#!/bin/bash
# ----------------------------------------------------------------------------
# Script: setup_kodi_env.sh
# Description: Configures Raspberry Pi OS (Bookworm) for optimal Kodi playback.
# Dynamically installs the latest major Kodi version available (kodi21, kodi22, etc.).
# ----------------------------------------------------------------------------

echo "--- Starting Idempotent Kodi Optimization Setup for RPi 500+ ---"

# Set configuration file paths
CONFIG_FILE="/boot/firmware/config.txt"
ENV_FILE="/etc/environment.d/20kodi.conf"
KODI_USER_GROUP="video"

# --- 1. Dynamic Version Detection and Installation ---
echo "[1/4] Detecting latest major Kodi version available..."

# Find the latest kodiXX-bin package, sort numerically, and take the last one.
# Example output: kodi21-bin
LATEST_KODI_BIN=$(apt-cache search kodi | awk '/^kodi[0-9][0-9]*-bin/ {print $1}' | sort -rV | head -n 1)

if [ -z "$LATEST_KODI_BIN" ]; then
    echo "ERROR: Could not find any dynamic kodiXX-bin package. Aborting installation."
    exit 1
fi

# Extract the base meta-package name (e.g., kodi21 from kodi21-bin)
KODI_PACKAGE="${LATEST_KODI_BIN%-bin}"
KODI_VERSION_NUMBER="${KODI_PACKAGE//[^0-9]/}"

echo "Found latest package: $KODI_PACKAGE (Version: $KODI_VERSION_NUMBER)"

# a) Remove old, conflicting package (kodi, not kodi21)
if dpkg -l | grep -q "^ii.*kodi " && ! dpkg -l | grep -q "kodi$KODI_VERSION_NUMBER-bin"; then
    echo "Removing legacy 'kodi' package before installing $KODI_PACKAGE."
    sudo apt remove -y kodi
fi

# b) Update and Install the Latest Version
sudo apt update
echo "Installing latest version: $KODI_PACKAGE."
sudo apt install -y "$KODI_PACKAGE"

# --- 2. User Permission Setup ---
echo "[2/4] Setting user permissions for hardware access (Idempotent)..."

if ! groups "$USER" | grep -q "$KODI_USER_GROUP"; then
    echo "Adding user $USER to '$KODI_USER_GROUP' group."
    sudo usermod -a -G "$KODI_USER_GROUP" "$USER"
else
    echo "User $USER is already in the '$KODI_USER_GROUP' group. Skipping."
fi


# --- 3. Configuration File Modifications (/boot/firmware/config.txt) ---
echo "[3/4] Modifying $CONFIG_FILE for Display and Performance (Idempotent)..."

# Function to add/modify lines without duplicating or causing conflicts
set_config() {
    KEY="$1"
    VALUE="$2"
    if grep -q "^${KEY}=" "$CONFIG_FILE"; then
        sudo sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG_FILE"
    else
        echo "${KEY}=${VALUE}" | sudo tee -a "$CONFIG_FILE" > /dev/null
    fi
}

if [ -f "$CONFIG_FILE" ]; then
    # Performance: Increase Contiguous Memory Allocator (CMA) for video buffers
    if ! grep -q "cma-512" "$CONFIG_FILE"; then
        echo "Setting cma-512 for video buffer size."
        sudo sed -i '/dtoverlay=vc4-kms-v3d/ s/$/\,cma-512/' "$CONFIG_FILE"
    else
        echo "CMA-512 already set. Skipping."
    fi

    # Display Configuration for Official 1080p Monitor
    echo "Setting HDMI display configuration."
    set_config hdmi_group 1
    set_config hdmi_mode 16
    set_config hdmi_drive 2
    set_config hdmi_pixel_encoding 2
    set_config disable_tv_dither 1

else
    echo "ERROR: Configuration file $CONFIG_FILE not found. Skipping edits."
fi

# --- 4. HDR Color Fix (Environment Variable) ---
echo "[4/4] Setting HDR color fix environment variable in $ENV_FILE (Idempotent)..."

# Ensure the file only contains the desired color fix variable
echo "LIBGL_DRM_OUTPUT_FORMAT=rgb" | sudo tee "$ENV_FILE" > /dev/null
echo "Set LIBGL_DRM_OUTPUT_FORMAT=rgb to $ENV_FILE."


echo "--- Setup Complete ---"
echo "A REBOOT IS REQUIRED to finalize permissions, display settings, and environment variables."
echo "Run 'sudo reboot' when you are ready."
