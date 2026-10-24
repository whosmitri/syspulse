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

## VERIFY IF THE SOURCE FILE EXIST

if [[ ! -f "$SOURCE_FILE" ]]; then
	echo "[ERROR] Paths file '$PATHS_FILE' not found!" >&2
	exit $EXIT_SOURCE_ERROR
fi

# print the confirmation
echo "[INFO] Reading list of paths from: $SOURCE_FILE"

## VALIDATE THAT EACH PATH EXISTS

# create an array for valid paths
VALID_PATHS=()

# iterate through each line, reading it as raw text (read -r)
# preserve whitespace (IFS=)
# store the content in the variable "path"
# OR  check if the "path" variable is non-empty (to hadle cases without a trailing newline)
while IFS= read -r path || [[ -n "$path" ]]; do
	# ignore empty lines or comments (lines starting with #)
	[[ -z "$path" || "$path" =~ ^# ]] && continue

	# check if the path exists (as a directory OR a file)
	if [[ -d "$path" ]] || [[ -f "$path" ]]; then
		VALID_PATHS+=("$path")
		# print the confirmation
		echo "[INFO] Path validated: $path"
	else
		# print the error
		echo "[ERROR] Configured path '$path' does not exist on the system!" >&2
		echo "[ERROR] Aborting backup to maintain integrity." >&2
		exit $EXIT_SOURCE_ERROR
	fi
done < "$SOURCE_FILE"

# ensure the list is not empty
if [[ ${#VALID_PATHS[@]} -eq 0 ]]; then
	echo "[ERROR] The file '$SOURCE_FILE' is empty or contains only comments." >&2
	exit $EXIT_SOURCE_ERROR
fi

# print confirmation
echo "[SUCCESS] All ${#VALID_PATHS[@]} path(s) have been successfully validated!"

## CREATE COMPRESSED FILE WITH TIMESTAMP

# generate the timestamp (date and time) in YYYY-MM-DD_HHMMSS format
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
ARCHIVE_NAME="syspulse-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

# notify the start of backup
echo "[INFO] Compressing ${#VALID_PATHS[@]} path(s) into: $ARCHIVE_PATH"

# compress using the array of valid paths
# create a new tar archive (-c)
# compress the archive (-z)
# specify the name of the file to be generated (-f)
# verify if the command executed with success
if tar -czf "$ARCHIVE_PATH" "${VALID_PATHS[@]}"; then
	echo "[SUCCESS] Backup completed successfully!"
	echo "[SUCCESS] File generated: $ARCHIVE_PATH"
	exit $EXIT_SUCCESS
else
	echo "[ERROR] Failed to write the compressed archive to the destination." >&2
	exit $EXIT_WRITE_ERROR
fi
