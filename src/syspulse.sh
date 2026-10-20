#!/bin/bash

# strict mode
set -euo pipefail

# define consts and exit modes
EXIT_SUCCESS=0
EXIT_SOURCE_ERROR=1
EXIT_WRITE_ERROR=2
EXIT_HARDWARE_ERROR=3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/syspulse.conf"

# find the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# find the config file
CONFIG_FILE="${SCRIPT_DIR}/syspulse.conf"

echo "$SCRIPT_DIR"
echo "$CONFIG_FILE"

# read the config file
if [[ ! -f "$CONFIG_FILE" ]]; then
	echo "[ERROR] Configuration file not found in: $CONFIG_FILE" >&2
	exit $EXIT_SOURCE_ERROR
fi

# load the variables from the config file
source "$CONFIG_FILE"

# temp test
echo "[INFO] Configuration loaded successfully!"
echo "[INFO] Backup destination: $BACKUP_DIR"
echo "[INFO] Disk alert threshold: $DISK_THRESHOLD%"

# hello !!
echo "hello, syspulse!"
