#!/usr/bin/env bash

# if VERBOSE is not set, default to false
: "${VERBOSE:=false}"

: "${LOG_FILE:="./syspulse.log"}"

log_msg()
{
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	local formatted_msg="${timestamp} [${level}] ${message}"

	# write everithing in log file
	echo "$formatted_msg" >> "$LOG_FILE"

	# determine what to display on screen based on the verbosity mode
	case "$level" in
		SUCCESS|INFO)
			# in compact/quit mode, skip INFO and SUCCESS
			if [[ "$VERBOSE" = true ]]; then
				echo -e "$formatted_msg"
			fi
			;;
		WARN|ERROR)
			# warnings and errors always appear on screen
			# error sent to stderr and in red!
			# warns in yellow
			if [[ "$level" = "ERROR" ]]; then
				echo -e "\033[31m$formatted_msg\033[0m" >&2
			else
				echo -e "\033[33m$formatted_msg\033[0m"
			fi
			;;
	*)
			echo -e "$formatted_msg"
			;;
	esac
}
