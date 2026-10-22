#!/bin/bash

# strict mode
set -euo pipefail

# define consts and exit modes
EXIT_SUCCESS=0
EXIT_SOURCE_ERROR=1
EXIT_WRITE_ERROR=2
EXIT_HARDWARE_ERROR=3

# find the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# find the config file
CONFIG_FILE="${SCRIPT_DIR}/syspulse.conf"

## READ THE CONFIG FILE

# check if the config file exist
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

## CHECK THE DISK USAGE

# check the target partition (df)
# print the usage percentage from the second line after the header (awk)
# and keep only the number (tr -d)
CURRENT_DISK_USAGE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | tr -d '%')

# print the disk usage
echo "[INFO] Current disk usage in '$BACKUP_DIR': ${CURRENT_DISK_USAGE}% (safe limit: ${DISK_THRESHOLD}%)"

# check if current usage is greater than or equal to the configured limit
if [[ "$CURRENT_DISK_USAGE" -ge "$DISK_THRESHOLD" ]]; then
	echo "[ERROR] Critically low disk space! Usage is at ${CURRENT_DISK_USAGE}%" >&2
	echo "[ERROR] Aborting backup to protect the system." >&2
	exit $EXIT_HARDWARE_ERROR
fi

# print confirmation
echo "[SUCCESS] Disk space verified. All clear to proceed!"

## CHECK THE RAM USAGE

# get the percentage of RAM usage (int number)
CURRENT_RAM_USAGE=$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {available=$2} END {print int((total - available) / total * 100)}' /proc/meminfo)

# print the RAM usage
echo "[INFO] Current RAM usage: ${CURRENT_RAM_USAGE}% (safe limit: ${RAM_THRESHOLD}%)"

# check if current usage is greater than or equal to theconfigured threshold
if [[ "$CURRENT_RAM_USAGE" -ge "$RAM_THRESHOLD" ]]; then
	echo "[ERROR] RAM usage is critically high!" >&2
	echo "[ERROR] Aborting backup to prevent an Out-of-Memory (OOM) event." >&2
	exit $EXIT_HARDWARE_ERROR
fi

# print confirmation
echo "[SUCCESS] RAM checked. System has sufficient resources available!"
