#!/bin/bash

set -euo pipefail

# Where did you download the .iso to?
DISCOVERY_ISO_HOST_PATH=/tmp/tmp.GtcQqzTn4y/discovery_image_test.iso

# After changing the above path, simply run this script as-is to create the ISO with your password
if [[ ! -f $DISCOVERY_ISO_HOST_PATH ]]; then
    echo "ERROR: Discovery ISO not found at $DISCOVERY_ISO_HOST_PATH"
else
    DISCOVERY_ISO_HOST_DIR=$(dirname $DISCOVERY_ISO_HOST_PATH)
    function COREOS_INSTALLER() {
        podman run -v "$DISCOVERY_ISO_HOST_DIR":/data --rm quay.io/coreos/coreos-installer:release "$@"
    }

    ISO_NAME=$(basename $DISCOVERY_ISO_HOST_PATH .iso)

    # Container paths
    DISCOVERY_ISO_PATH=/data/${ISO_NAME}.iso
    DISCOVERY_ISO_WITH_PASSWORD=/data/${ISO_NAME}_with_password.iso

    # Host output path
    DISCOVERY_ISO_WITH_PASSWORD_HOST=$(dirname "$DISCOVERY_ISO_HOST_PATH")/$(basename "$DISCOVERY_ISO_WITH_PASSWORD")

    # Prompt
    USER_PASSWORD=$(mkpasswd --method=SHA-512)

    # Transform original ignition
    TRANSFORMED_IGNITION_PATH=$(mktemp --tmpdir="$DISCOVERY_ISO_HOST_DIR")
    TRANSFORMED_IGNITION_NAME=$(basename "$TRANSFORMED_IGNITION_PATH")
    COREOS_INSTALLER iso ignition show "$DISCOVERY_ISO_PATH" | jq --arg pass "$USER_PASSWORD" '.passwd.users[0].passwordHash = $pass' > "$TRANSFORMED_IGNITION_PATH"

    # Generate new ISO
    rm -f "$DISCOVERY_ISO_WITH_PASSWORD_HOST" \
        && COREOS_INSTALLER iso customize --output "$DISCOVERY_ISO_WITH_PASSWORD" --force "$DISCOVERY_ISO_PATH" --live-ignition /data/"$TRANSFORMED_IGNITION_NAME" \
        && echo 'Created ISO with your password in "'"$DISCOVERY_ISO_WITH_PASSWORD_HOST"'", the login username is "core"'

    # Cleanup
    unset USER_PASSWORD DISCOVERY_ISO_HOST_PATH DISCOVERY_ISO_PATH DISCOVERY_ISO_WITH_PASSWORD DISCOVERY_ISO_WITH_PASSWORD_HOST
    unset -f COREOS_INSTALLER
fi
