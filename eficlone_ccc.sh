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

function main () {
	validateParamCount 4 $#

	echoLog 'Running in "Carbon Copy Cloner" mode:'
	echoLog "1: Source Path = $1"
	echoLog "2: Destination Path = $2"
	echoLog "3: CCC Exit Status = $3"
	echoLog "4: Disk image file path = $4"

	if [[ "$3" == "0" ]]; then
		echoLog 'Check passed: CCC completed with success.'
	else
		failGracefully 'CCC did not exit with success.' 'CCC task failed.'
	fi

	if [[ "$4" == "" ]]; then
		echoLog "Check passed: CCC clone was not to a disk image."
	else
		failGracefully 'CCC clone destination was a disk image file.' 'CCC disk image clone destinations are not supported.'
	fi

	sourceVolume=$1
	destinationVolume=$2

 	[[ "$TEST_SWITCH" == "Y" ]] && dryFlag='--dry-run'
	bash ./eficlone.sh $dryFlag "$sourceVolume" "$destinationVolume"
}

[[ -f "$LOG_FILE" ]] && rm "$LOG_FILE"
main "$@" >> ${LOG_FILE}
