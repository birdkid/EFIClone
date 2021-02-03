#!/bin/bash
# EFI Partition Clone Script

# Created by Ted Howe (c) 2018 | tedhowe@burke-howe.com | GitHub: wombat94 | TonyMacx86: wombat94
# Modified by kobaltcore 2019 | cobaltcore@yandex.com | GitHub: kobaltkore | TonyMacx86: byteminer
# Modified by Bird-Kid 2020 | GitHub: Bird-Kid | TonyMacx86: Bird-Kid

# This script is designed to be run automatically by CCC.
# This script can be invoked as "post-flight" script at the end of a clone
# task. It will copy the contents of the source drive's EFI partition to the
# destination drive's EFI partition. It will COMPLETELY DELETE and replace all
# data on the destination EFI partition.

# THIS SCRIPT MODIFIES DATA AND AS SUCH CAN CAUSE DATA LOSS!
# Use this at your own risk.
# We've tried to make it as safe as possible, but nobody's perfect.

source utils.sh
source eficlone_postflight_settings.sh

function main() {
	validate_param_count 4 $#

	echo_log 'Running in "Carbon Copy Cloner" mode:'
	echo_log "1: Source Path = $1"
	echo_log "2: Destination Path = $2"
	echo_log "3: CCC Exit Status = $3"
	echo_log "4: Disk image file path = $4"

	if [[ "$3" == "0" || "$3" == "2150" ]]; then
		echo_log 'Check passed: CCC completed with success.'
	else
		fail_gracefully 'CCC did not exit with success.' 'CCC task failed.'
	fi

	if [[ "$4" == "" ]]; then
		echo_log "Check passed: CCC clone was not to a disk image."
	else
		fail_gracefully 'CCC clone destination was a disk image file.' 'CCC disk image clone destinations are not supported.'
	fi

	local source_volume=$1
	local destination_volume=$2

 	[[ "$TEST_SWITCH" == "Y" ]] && dryFlag='--dry-run'
	bash ./eficlone.sh $dryFlag "$source_volume" "$destination_volume"
}

[[ -f "$LOG_FILE" ]] && rm "$LOG_FILE"
main "$@" >> ${LOG_FILE}
