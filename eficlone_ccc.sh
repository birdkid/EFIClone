#!/bin/bash
# EFI Partition Clone Script
# Created by Ted Howe (c) 2018 | tedhowe@burke-howe.com | wombat94 on GitHub   | wombat94 on TonyMacx86
# Modified by kobaltcore 2019  | cobaltcore@yandex.com  | kobaltkore on GitHub | byteminer on TonyMacx86
# Modified by Bird-Kid 2020    |                        | Bird-Kid on GitHub   | Bird-Kid on TonyMacx86

# This script is designed to be a "post-flight" script run automatically by CCC at the end of a
# clone task. It will copy the contents of the source drive's EFI partition to the destination drive's EFI
# partition. It will COMPLETELY DELETE and replace all data on the destination EFI partition.

# THIS SCRIPT MODIFIES DATA AND AS SUCH CAN CAUSE DATA LOSS!
# Use this at your own risk. We've tried to make it as safe as possible, but nobody's perfect.

source utils.sh
source eficlone_postflight_settings.sh

function main () {
	validateParamCount 4 $#

	writeTolog 'Running in "Carbon Copy Cloner" mode:'
	writeTolog "1: Source Path = $1"
	writeTolog "2: Destination Path = $2"
	writeTolog "3: CCC Exit Status = $3"
	writeTolog "4: Disk image file path = $4"

	if [[ "$3" == "0" ]]; then
		writeTolog 'Check passed: CCC completed with success.'
	else
		failGracefully 'CCC did not exit with success.' 'CCC task failed.'
	fi

	if [[ "$4" == "" ]]; then
		writeTolog "Check passed: CCC clone was not to a disk image."
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
