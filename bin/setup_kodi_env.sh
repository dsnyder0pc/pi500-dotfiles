#!/bin/bash
# ----------------------------------------------------------------------------
# Script: setup_kodi_env.sh
# Description: Configures Raspberry Pi OS for optimal Kodi playback.
# Dynamically installs the latest major Kodi version available (kodi21, kodi22, etc.).
# --- Auto-detection of Headless / Desktop Environment ---
# A system is considered headless if it lacks a Wayland compositor or X server, and does not boot to a graphical target by default.
HEADLESS=true
if command -v labwc &>/dev/null || command -v wayfire &>/dev/null || command -v Xorg &>/dev/null; then
    HEADLESS=false
elif command -v systemctl &>/dev/null && [ "$(systemctl get-default)" = "graphical.target" ]; then
    HEADLESS=false
fi

# Support manual override via flags
for arg in "$@"; do
  case $arg in
    --headless|--no-gui) HEADLESS=true ;;
    --gui) HEADLESS=false ;;
  esac
done

if [ "$HEADLESS" = true ]; then
    echo "ERROR: System is in headless/no-GUI mode. Skipping Kodi installation and configuration."
    exit 0
fi

echo "--- Starting Idempotent Kodi Optimization Setup for RPi 500+ ---"

# Set configuration file paths
CONFIG_FILE=""
if [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f "/boot/config.txt" ]; then
    CONFIG_FILE="/boot/config.txt"
fi

ENV_FILE="/etc/environment.d/20kodi.conf"
KODI_USER_GROUP="video"

# --- 1. Dynamic Version Detection and Installation ---
echo "[1/4] Detecting latest major Kodi version available..."

if command -v pacman &>/dev/null; then
    # Arch Linux / CachyOS
    if pacman -Si kodi &>/dev/null; then
        KODI_PACKAGE="kodi"
        CANDIDATE_VER=$(pacman -Si kodi | awk '/^Version/ {print $3}')
        # Extract major version number (e.g., 21.3-5 -> 21)
        KODI_VERSION_NUMBER="${CANDIDATE_VER%%.*}"
    else
        echo "ERROR: Could not find kodi package in pacman repositories. Aborting installation."
        exit 1
    fi

    echo "Found latest package: $KODI_PACKAGE (Version: $KODI_VERSION_NUMBER)"

    # Install the Latest Version
    echo "Installing latest version: $KODI_PACKAGE."
    sudo pacman -S --needed --noconfirm "$KODI_PACKAGE"

elif command -v apt-get &>/dev/null; then
    # Debian / Raspberry Pi OS
    sudo apt update
    LATEST_KODI_BIN=$(apt-cache search kodi | awk '/^kodi[0-9][0-9]*-bin/ {print $1}' | sort -rV | head -n 1)

    if [ -z "$LATEST_KODI_BIN" ]; then
        # Fallback to standard kodi package if available
        if apt-cache show kodi &>/dev/null; then
            echo "No dynamic kodiXX-bin package found. Falling back to standard 'kodi' package."
            KODI_PACKAGE="kodi"
            # Get the major version number from the candidate version (e.g., 3:21.3+dfsg-1 -> 21)
            CANDIDATE_VER=$(apt-cache policy kodi | awk '/Candidate:/ {print $2}')
            if [[ "$CANDIDATE_VER" == *:* ]]; then
                CANDIDATE_VER="${CANDIDATE_VER#*:}"
            fi
            KODI_VERSION_NUMBER="${CANDIDATE_VER%%.*}"
        else
            echo "ERROR: Could not find any dynamic kodiXX-bin package or standard kodi package. Aborting installation."
            exit 1
        fi
    else
        # Extract the base meta-package name (e.g., kodi21 from kodi21-bin)
        KODI_PACKAGE="${LATEST_KODI_BIN%-bin}"
        KODI_VERSION_NUMBER="${KODI_PACKAGE//[^0-9]/}"
    fi

    echo "Found latest package: $KODI_PACKAGE (Version: $KODI_VERSION_NUMBER)"

    # a) Remove old, conflicting package (kodi, not kodi21)
    if [ "$KODI_PACKAGE" != "kodi" ] && dpkg -l | grep -q "^ii.*kodi " && ! dpkg -l | grep -q "kodi$KODI_VERSION_NUMBER-bin"; then
        echo "Removing legacy 'kodi' package before installing $KODI_PACKAGE."
        sudo apt remove -y kodi
    fi

    # b) Update and Install the Latest Version
    echo "Installing latest version: $KODI_PACKAGE."
    sudo apt install --upgrade -y "$KODI_PACKAGE"
else
    echo "ERROR: Unsupported package manager (neither pacman nor apt found). Aborting."
    exit 1
fi

# --- 2. User Permission Setup ---
echo "[2/4] Setting user permissions for hardware access (Idempotent)..."

if ! groups "$USER" | grep -q "$KODI_USER_GROUP"; then
    echo "Adding user $USER to '$KODI_USER_GROUP' group."
    sudo usermod -a -G "$KODI_USER_GROUP" "$USER"
else
    echo "User $USER is already in the '$KODI_USER_GROUP' group. Skipping."
fi


# --- 3. Configuration File Modifications (config.txt) ---
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
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
    echo "[3/4] No Raspberry Pi firmware config.txt file found. Skipping configuration edits."
fi

# --- 4. HDR Color Fix (Environment Variable) ---
echo "[4/4] Setting HDR color fix environment variable in $ENV_FILE (Idempotent)..."

# Ensure the target directory exists
sudo mkdir -p "$(dirname "$ENV_FILE")"

# Ensure the file only contains the desired color fix variable
echo "LIBGL_DRM_OUTPUT_FORMAT=rgb" | sudo tee "$ENV_FILE" > /dev/null
echo "Set LIBGL_DRM_OUTPUT_FORMAT=rgb to $ENV_FILE."


echo "--- Setup Complete ---"
echo "A REBOOT IS REQUIRED to finalize permissions, display settings, and environment variables."
echo "Run 'sudo reboot' when you are ready."
