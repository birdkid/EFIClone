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
	validateParamCount 6 $#

	echoLog 'Running in "SuperDuper" mode:'
	echoLog "1: Source Disk Name = $1"
	echoLog "2: Source Mount Path = $2"
	echoLog "3: Destination Disk Name = $3"
	echoLog "4: Destination Mount Path = $4"
	echoLog "5: SuperDuper! Backup Script Used = $5"
	echoLog "6: Unused parameter 6 = $6"

	sourceVolume=$2
	destinationVolume=$4

 	[[ "$TEST_SWITCH" == "Y" ]] && dryFlag='--dry-run'
	bash ./eficlone.sh --dry-run "$sourceVolume" "$destinationVolume"
}

[[ -f "$LOG_FILE" ]] && rm "$LOG_FILE"
main "$@" >> ${LOG_FILE}
