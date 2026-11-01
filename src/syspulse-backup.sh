#!/bin/bash

# strict mode
set -euo pipefail

# define consts and exit modes
EXIT_SUCCESS=0
EXIT_SOURCE_ERROR=1
EXIT_WRITE_ERROR=2
EXIT_HARDWARE_ERROR=3

# set the default to quiet/compact
VERBOSE=false
# scan the arguments passe by command line
while [[ $# -gt 0 ]]; do
	case "$1" in
		-v|--verbose)
			VERBOSE=true
			# move to the next argument
			shift
			;;
		*)
			# ignore other unknown args
			shift
			;;
	esac
done

# find the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# find the config file
CONFIG_FILE="${SCRIPT_DIR}/syspulse.conf"

## READ THE CONFIG FILE

# check if the config file exist
if [[ ! -f "$CONFIG_FILE" ]]; then
	log_msg "ERROR" "Configuration file not found in: $CONFIG_FILE"
	exit $EXIT_SOURCE_ERROR
fi

# load the variables from the config file
source "$CONFIG_FILE"
# load the log module
source "${SCRIPT_DIR}/syspulse-logger.sh"

# temp test
log_msg "INFO" "Configuration loaded successfully!"
log_msg "INFO" "Backup destination: $BACKUP_DIR"
log_msg "INFO" "Disk alert threshold: $DISK_THRESHOLD%"

## CHECK THE DISK USAGE

# check the target partition (df)
# print the usage percentage from the second line after the header (awk)
# and keep only the number (tr -d)
CURRENT_DISK_USAGE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | tr -d '%')

# print the disk usage
log_msg "INFO" "Current disk usage in '$BACKUP_DIR': ${CURRENT_DISK_USAGE}% (safe limit: ${DISK_THRESHOLD}%)"

# check if current usage is greater than or equal to the configured limit
if [[ "$CURRENT_DISK_USAGE" -ge "$DISK_THRESHOLD" ]]; then
	log_msg "ERROR" "Critically low disk space! Usage is at ${CURRENT_DISK_USAGE}%"
	log_msg "ERROR" "Aborting backup to protect the system."
	exit $EXIT_HARDWARE_ERROR
fi

# print confirmation
log_msg "SUCCESS" "Disk space verified. All clear to proceed!"

## CHECK THE RAM USAGE

# get the percentage of RAM usage (int number)
CURRENT_RAM_USAGE=$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {available=$2} END {print int((total - available) / total * 100)}' /proc/meminfo)

# print the RAM usage
log_msg "INFO" "Current RAM usage: ${CURRENT_RAM_USAGE}% (safe limit: ${RAM_THRESHOLD}%)"

# check if current usage is greater than or equal to theconfigured threshold
if [[ "$CURRENT_RAM_USAGE" -ge "$RAM_THRESHOLD" ]]; then
	log_msg "ERROR" "RAM usage is critically high!"
	log_msg "ERROR" "Aborting backup to prevent an Out-of-Memory (OOM) event."
	exit $EXIT_HARDWARE_ERROR
fi

# print confirmation
log_msg "SUCCESS" "RAM checked. System has sufficient resources available!"

## VERIFY IF THE SOURCE FILE EXIST

if [[ ! -f "$SOURCE_FILE" ]]; then
	log_msg "ERROR" "Paths file '$PATHS_FILE' not found!"
	exit $EXIT_SOURCE_ERROR
fi

# print the confirmation
log_msg "INFO" "Reading list of paths from: $SOURCE_FILE"

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
		log_msg "INFO" "Path validated: $path"
	else
		# print the error
		log_msg "ERROR" "Configured path '$path' does not exist on the system!"
		log_msg "ERROR" "Aborting backup to maintain integrity."
		exit $EXIT_SOURCE_ERROR
	fi
done < "$SOURCE_FILE"

# ensure the list is not empty
if [[ ${#VALID_PATHS[@]} -eq 0 ]]; then
	log_msg "ERROR" "The file '$SOURCE_FILE' is empty or contains only comments."
	exit $EXIT_SOURCE_ERROR
fi

# print confirmation
log_msg "SUCCESS" "All ${#VALID_PATHS[@]} path(s) have been successfully validated!"

## CREATE COMPRESSED FILE WITH TIMESTAMP

# generate the timestamp (date and time) in YYYY-MM-DD_HHMMSS format
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
ARCHIVE_NAME="syspulse-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

# notify the start of backup
log_msg "INFO" "Compressing ${#VALID_PATHS[@]} path(s) into: $ARCHIVE_PATH"

# compress using the array of valid paths
# create a new tar archive (-c)
# compress the archive (-z)
# specify the name of the file to be generated (-f)
# verify if the command executed with success
if tar -czf "$ARCHIVE_PATH" "${VALID_PATHS[@]}"; then
	log_msg "SUCCESS" "Backup completed successfully!"
	log_msg "SUCCESS" "File generated: $ARCHIVE_PATH"
else
	log_msg "ERROR" "Failed to write the compressed archive to the destination."
	exit $EXIT_WRITE_ERROR
fi

## KEEP ONLY THE LAST "N" BACKUPS

log_msg "INFO" "Applying retention policy (keeping the last ${RETENTION_COUNT} backups)"

# enter the backup directory to manage files safely
cd "$BACKUP_DIR" || exit $EXIT_SOURCE_ERROR

# list files from newest to oldest, one item per line (-1t)
# hide/redirect any error messages if the folder is empty
# skip the first N files (tail -n +X)
# delete the rest, if any exist
ls -1t syspulse-*.tar.gz 2>/dev/null | tail -n +$((RETENTION_COUNT + 1)) | while read -r old_backup; do
	if [[ -n "$old_backup" ]]; then
		rm -f "$old_backup"
		log_msg "INFO" "Removed excess old backup: $old_backup"
	fi
done

# return to the last directory
cd - > /dev/null

log_msg "SUCCESS" "Retention policy applied successfully!"

log_msg "SUCCESS" "Backup complete and cycle finished!"
exit $EXIT_SUCCESS

