#!/usr/bin/env bash

#strict mode
set -euo pipefail

# define consts and exit modes
EXIT_SUCCESS=0
EXIT_SOURCE_ERROR=1
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
	exit $EXIT_HARDWARE_ERROR
fi

# print confirmation
log_msg "SUCCESS" "RAM checked. System has sufficient resources available!"

# return success exit code!
exit $EXIT_SUCCESS
