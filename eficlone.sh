#!/bin/bash
# EFI Partition Clone Script

# Created by Ted Howe (c) 2018 | tedhowe@burke-howe.com | GitHub: wombat94 | TonyMacx86: wombat94
# Modified by kobaltcore 2019 | cobaltcore@yandex.com | GitHub: kobaltkore | TonyMacx86: byteminer
# Modified by Bird-Kid 2020 | GitHub: Bird-Kid | TonyMacx86: Bird-Kid

# This script will copy the contents of the source drive's EFI partition to the
# destination drive's EFI partition. It will COMPLETELY DELETE and replace all
# data on the destination EFI partition.

# THIS SCRIPT MODIFIES DATA AND AS SUCH CAN CAUSE DATA LOSS!
# Use this at your own risk.
# We've tried to make it as safe as possible, but nobody's perfect.

source utils.sh

dryMode=''
sourceVolume=''
destinationVolume=''
while [[ "$#" > 0 ]]; do
	case "$1" in
		-n|--dry-run) dryMode=1;;
		-h|--help) usage;;
		-*) usage "Unknown parameter received: $1";;
		*)
			sourceVolume="$1"
			destinationVolume="$2"
			[ -n "$3" ] && usage 'Unknown extra arguments received.'
			shift
			;;
	esac
	shift
done

[[ "$sourceVolume" == '' ]] && usage 'Please specify a source volume.'
[[ "$destinationVolume" == '' ]] && usage 'Please specify a destination volume.'

echoLog 'Starting EFI Clone Script...'

if [[ -n "$dryMode" ]]; then
	echoLog "Running $0 in dry mode..."
else
	echoLog "Running $0..."
fi


## Source Target.

echoLog "sourceVolume = $sourceVolume"

sourceVolumeDisk="$( getDiskNumber "$sourceVolume" )"
# If we can't figure out the path, we're probably running on Mojave or later,
# where CCC creates a temporary mount point. We use the help of "df" to output
# the volume of that mount point, afterwards it's business as usual.
if [[ "$sourceVolumeDisk" == "" ]]; then
	sourceVolume=$( df "$sourceVolume" 2>/dev/null | grep /dev | cut -d ' ' -f 1 | cut -d '@' -f 2 )
	if [[ "$sourceVolume" != "" ]]; then
		sourceVolumeDisk="$( getDiskNumber "$sourceVolume" )"
	fi
fi

if [[ "$sourceVolumeDisk" == "" ]]; then
	failGracefully 'Source Volume Disk not found.'
fi

sourceEFIPartition="$( getEFIPartition "$sourceVolumeDisk" )"

echoLog "sourceVolumeDisk = $sourceVolumeDisk"
echoLog "sourceEFIPartition = $sourceEFIPartition"


## Destination Target.

echoLog "destinationVolume = $destinationVolume"

destinationVolumeDisk="$( getDiskNumber "$destinationVolume" )"

if [[ "$destinationVolumeDisk" == "" ]]; then
	failGracefully 'Destination Volume Disk not found.'
fi

destinationEFIPartition="$( getEFIPartition "$destinationVolumeDisk" )"

echoLog "destinationVolumeDisk = $destinationVolumeDisk"
echoLog "destinationEFIPartition = $destinationEFIPartition"


## Sanity Checks.

if [[ "$sourceEFIPartition" == "" ]]; then
	failGracefully 'EFI source partition not found.'
fi

if [[ "$destinationEFIPartition" == "" ]]; then
	failGracefully 'EFI destination partition not found.'
fi

if [[ "$sourceEFIPartition" == "$destinationEFIPartition" ]]; then
	failGracefully 'EFI source and destination partitions are the same.'
fi

sourceEFIPartitionSplit=($sourceEFIPartition)
if [ "${#sourceEFIPartitionSplit[@]}" -gt 1 ]; then
	failGracefully 'Multiple EFI source partitions found.'
fi

destinationEFIPartitionSplit=($destinationEFIPartition)
if [ "${#destinationEFIPartitionSplit[@]}" -gt 1 ]; then
	failGracefully 'Multiple EFI destination partitions found.'
fi


## Mount Targets.

diskutil quiet mount readOnly /dev/$sourceEFIPartition
if (( $? != 0 )); then
	failGracefully 'Mounting EFI source partition failed.'
fi

diskutil quiet mount /dev/$destinationEFIPartition
if (( $? != 0 )); then
	failGracefully 'Mounting EFI destination partition failed.'
fi

echoLog 'Drives mounted.'
sourceEFIMountPoint="$( getDiskMountPoint "$sourceEFIPartition" )"
echoLog "sourceEFIMountPoint = $sourceEFIMountPoint"

destinationEFIMountPoint="$( getDiskMountPoint "$destinationEFIPartition" )"
echoLog "destinationEFIMountPoint = $destinationEFIMountPoint"


## Synchronize.

if [[ -n "$dryMode" ]]; then
	echoLog 'Simulating file synchronization...'
	echoLog 'The following rsync command will be executed with the "--dry-run" option:'
	echoLog "rsync -av --exclude='.*'' \"$sourceEFIMountPoint/\" \"$destinationEFIMountPoint/\""
	echoLog "THE BELOW OUTPUT IS FROM AN RSYNC DRY RUN! NO DATA HAS BEEN MODIFIED!"
	echo '----------------------------------------'
	rsync --dry-run -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/"
	echo '----------------------------------------'
else
	echoLog "Synchronizing files from $sourceEFIMountPoint/EFI to $destinationEFIMountPoint..."
	echo '----------------------------------------'
	rsync -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/"
	echo '----------------------------------------'
fi


## Validate Destination.

echoLog 'Comparing checksums of EFI directories...'
echoLog "Source directory hash:"
echo '----------------------------------------'
sourceEFIHash="$( collectEFIHash "$sourceEFIMountPoint" )"
echo -e "$sourceEFIHash"
echo '----------------------------------------'
echoLog "Destination directory hash:"
echo '----------------------------------------'
destinationEFIHash="$( collectEFIHash "$destinationEFIMountPoint" )"
echo -e "$destinationEFIHash"
echo '----------------------------------------'

diskutil quiet unmount /dev/$destinationEFIPartition
diskutil quiet unmount /dev/$sourceEFIPartition
echoLog 'EFI partitions unmounted.'

if [[ -z "$dryMode" ]]; then
	if [[ "$sourceEFIHash" == "$destinationEFIHash" ]]; then
		echoLog "Directory hashes match; files copied successfully."
		displayNotification 'EFI Clone Script completed successfully.'
	else
		failGracefully 'Directory hashes differ; copying failed.' 'EFI copied unsuccessfully; files do not match source.'
	fi
fi

echoLog 'EFI Clone Script completed.'

exit 0
