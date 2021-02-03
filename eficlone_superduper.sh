#!/bin/bash
# EFI Partition Clone Script

# Created by Ted Howe (c) 2018 | tedhowe@burke-howe.com | GitHub: wombat94 | TonyMacx86: wombat94
# Modified by kobaltcore 2019 | cobaltcore@yandex.com | GitHub: kobaltkore | TonyMacx86: byteminer
# Modified by Bird-Kid 2020 | GitHub: Bird-Kid | TonyMacx86: Bird-Kid

# This script is designed to be run automatically by SuperDuper!.
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
	validate_param_count 6 $#

	echo_log 'Running in "SuperDuper" mode:'
	echo_log "1: Source Disk Name = $1"
	echo_log "2: Source Mount Path = $2"
	echo_log "3: Destination Disk Name = $3"
	echo_log "4: Destination Mount Path = $4"
	echo_log "5: SuperDuper! Backup Script Used = $5"
	echo_log "6: Unused parameter 6 = $6"

	local source_volume=$2
	local destination_volume=$4

 	[[ "$TEST_SWITCH" == "Y" ]] && dryFlag='--dry-run'
	bash ./eficlone.sh --dry-run "$source_volume" "$destination_volume"
}

[[ -f "$LOG_FILE" ]] && rm "$LOG_FILE"
main "$@" >> ${LOG_FILE}
