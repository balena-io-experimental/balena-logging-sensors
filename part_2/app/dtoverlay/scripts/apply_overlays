#!/bin/sh
set -e

print_help() {
  echo "apply_overlays - Attempt to dynamically apply compiled overlays to the running kernel."
  echo "Usage:"
  echo "  apply_overlays [list of compiled overlays to apply]"
  echo "Example:"
  echo "  apply_overlays foo bar"
  echo "This will attempt to apply the foo.dtbo and bar.dtbo from the overlays" \
       "folder to the running kernel (notice you do not need to specify the .dtbo" \
       "extension).  Overlay .dtbo files are searched for in the overlays folder" \
       "(default location: $OVERLAYS_DIR) and applied using the kernel's device" \
       "tree ConfigFS system.  You can change the overlays folder location by" \
       "setting the OVERLAYS_DIR environment variable."
  echo
  echo "WARNING: Dynamically applying device tree overlays is a best effort" \
       "with known problems and limitations in the kernel!  If an overlay" \
       "cannot be dynamically loaded you must fall back to loading it at boot" \
       "through the mechanisms available to your board's bootloader."
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  print_help
  exit 0
fi

# Attempt to load the configfs tree for the device tree.
mount -t configfs none /sys/kernel/config
if [ ! -d /sys/kernel/config/device-tree ]; then
  echo "apply_overlays: Failed to find device tree ConfigFS root under" \
       "/sys/kernel/config/device-tree. Ensure the kernel has been compiled" \
       "with device tree ConfigFS support."
  exit 1
fi

# Loop through each of the parameters after the first and attempt to load to
# load them as device tree overlays.
cd $OVERLAYS_DIR
for OVERLAY in "$@"; do
  OVERLAY=${OVERLAY%.dtbo} # Strip off .dtbo if it was specified accidentally.
  OVERLAY_FILE=$OVERLAY.dtbo
  if [ ! -r "$OVERLAY_FILE" ]; then
    echo "apply_overlays: Failed to find overlay: $OVERLAY_FILE"
    exit 1
  fi
  echo "apply_overlays: Applying overlay $OVERLAY_FILE"
  mkdir -p /sys/kernel/config/device-tree/overlays/$OVERLAY
  cat $OVERLAY_FILE > /sys/kernel/config/device-tree/overlays/$OVERLAY/dtbo
done

exit 0
