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

echo_log 'Starting EFI Clone Script...'

if [[ -n "$dryMode" ]]; then
	echo_log "Running $0 in dry mode..."
else
	echo_log "Running $0..."
fi


## Source Target.

echo_log "sourceVolume = $sourceVolume"

sourceVolumeDisk="$(get_disk_number "$sourceVolume")"
# If we can't figure out the path, we're probably running on Mojave or later,
# where CCC creates a temporary mount point. We use the help of "df" to output
# the volume of that mount point, afterwards it's business as usual.
if [[ "$sourceVolumeDisk" == "" ]]; then
	sourceVolume=$( df "$sourceVolume" 2>/dev/null | grep /dev | cut -d ' ' -f 1 | cut -d '@' -f 2 )
	if [[ "$sourceVolume" != "" ]]; then
		sourceVolumeDisk="$(get_disk_number "$sourceVolume")"
	fi
fi

if [[ "$sourceVolumeDisk" == "" ]]; then
	fail_gracefully 'Source Volume Disk not found.'
fi

sourceEFIPartition="$(get_efi_partition "$sourceVolumeDisk")"

echo_log "sourceVolumeDisk = $sourceVolumeDisk"
echo_log "sourceEFIPartition = $sourceEFIPartition"


## Destination Target.

echo_log "destinationVolume = $destinationVolume"

destinationVolumeDisk="$(get_disk_number "$destinationVolume")"

if [[ "$destinationVolumeDisk" == "" ]]; then
	fail_gracefully 'Destination Volume Disk not found.'
fi

destinationEFIPartition="$(get_efi_partition "$destinationVolumeDisk")"

echo_log "destinationVolumeDisk = $destinationVolumeDisk"
echo_log "destinationEFIPartition = $destinationEFIPartition"


## Sanity Checks.

if [[ "$sourceEFIPartition" == "" ]]; then
	fail_gracefully 'EFI source partition not found.'
fi

if [[ "$destinationEFIPartition" == "" ]]; then
	fail_gracefully 'EFI destination partition not found.'
fi

if [[ "$sourceEFIPartition" == "$destinationEFIPartition" ]]; then
	fail_gracefully 'EFI source and destination partitions are the same.'
fi

sourceEFIPartitionSplit=($sourceEFIPartition)
if [ "${#sourceEFIPartitionSplit[@]}" -gt 1 ]; then
	fail_gracefully 'Multiple EFI source partitions found.'
fi

destinationEFIPartitionSplit=($destinationEFIPartition)
if [ "${#destinationEFIPartitionSplit[@]}" -gt 1 ]; then
	fail_gracefully 'Multiple EFI destination partitions found.'
fi


## Mount Targets.

diskutil quiet mount readOnly /dev/$sourceEFIPartition
if (( $? != 0 )); then
	fail_gracefully 'Mounting EFI source partition failed.'
fi

diskutil quiet mount /dev/$destinationEFIPartition
if (( $? != 0 )); then
	fail_gracefully 'Mounting EFI destination partition failed.'
fi

echo_log 'Drives mounted.'
sourceEFIMountPoint="$(get_disk_mount_point "$sourceEFIPartition")"
echo_log "sourceEFIMountPoint = $sourceEFIMountPoint"

destinationEFIMountPoint="$(get_disk_mount_point "$destinationEFIPartition")"
echo_log "destinationEFIMountPoint = $destinationEFIMountPoint"


## Synchronize.

if [[ -n "$dryMode" ]]; then
	echo_log 'Simulating file synchronization...'
	echo_log 'The following rsync command will be executed with the "--dry-run" option:'
	echo_log "rsync -av --exclude='.*'' \"$sourceEFIMountPoint/\" \"$destinationEFIMountPoint/\""
	echo_log "THE BELOW OUTPUT IS FROM AN RSYNC DRY RUN! NO DATA HAS BEEN MODIFIED!"
	echo '----------------------------------------'
	rsync --dry-run -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/"
	echo '----------------------------------------'
else
	echo_log "Synchronizing files from $sourceEFIMountPoint/EFI to $destinationEFIMountPoint..."
	echo '----------------------------------------'
	rsync -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/"
	echo '----------------------------------------'
fi


## Validate Destination.

echo_log 'Comparing checksums of EFI directories...'
echo_log "Source directory hash:"
echo '----------------------------------------'
sourceEFIHash="$(collect_efi_hash "$sourceEFIMountPoint")"
echo -e "$sourceEFIHash"
echo '----------------------------------------'
echo_log "Destination directory hash:"
echo '----------------------------------------'
destinationEFIHash="$(collect_efi_hash "$destinationEFIMountPoint")"
echo -e "$destinationEFIHash"
echo '----------------------------------------'

diskutil quiet unmount /dev/$destinationEFIPartition
diskutil quiet unmount /dev/$sourceEFIPartition
echo_log 'EFI partitions unmounted.'

if [[ -z "$dryMode" ]]; then
	if [[ "$sourceEFIHash" == "$destinationEFIHash" ]]; then
		echo_log "Directory hashes match; files copied successfully."
		display_notification 'EFI Clone Script completed successfully.'
	else
		fail_gracefully 'Directory hashes differ; copying failed.' 'EFI copied unsuccessfully; files do not match source.'
	fi
fi

echo_log 'EFI Clone Script completed.'

exit 0
