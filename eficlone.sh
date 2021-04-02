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

# Strict mode.
set -euo pipefail
IFS=$'\n\t'

APP_DIR="$(dirname "$0")"

source "$APP_DIR/utils.sh"

dry_mode=''
source_volume=''
destination_volume=''
while [[ "$#" > 0 ]]; do
	case "${1-}" in
		-n|--dry-run) dry_mode=1;;
		-h|--help) usage;;
		-*) usage "Unknown parameter received: $1";;
		*)
			source_volume="$1"
			destination_volume="$2"
			[ -n "${3-}" ] && usage 'Unknown extra arguments received.'
			shift
			;;
	esac
	shift
done

[[ "$source_volume" == '' ]] && usage 'Please specify a source volume.'
[[ "$destination_volume" == '' ]] && usage 'Please specify a destination volume.'

echo_log 'Starting EFI Clone Script...'

if [[ -n "$dry_mode" ]]; then
	echo_log "Running $0 in dry mode..."
else
	echo_log "Running $0..."
fi


## Source Target.

echo_log "source_volume = $source_volume"

source_volume_disk="$(get_disk_number "$source_volume")"
# If we can't figure out the path, we're probably running on Mojave or later,
# where CCC creates a temporary mount point. We use the help of "df" to output
# the volume of that mount point, afterwards it's business as usual.
if [[ "$source_volume_disk" == "" ]]; then
	source_volume=$( df "$source_volume" 2>/dev/null | grep /dev | cut -d ' ' -f 1 | cut -d '@' -f 2 )
	if [[ "$source_volume" != "" ]]; then
		source_volume_disk="$(get_disk_number "$source_volume")"
	fi
fi

if [[ "$source_volume_disk" == "" ]]; then
	fail_gracefully 'Source Volume Disk not found.'
fi

source_efi_partition="$(get_efi_partition "$source_volume_disk")"

echo_log "source_volume_disk = $source_volume_disk"
echo_log "source_efi_partition = $source_efi_partition"


## Destination Target.

echo_log "destination_volume = $destination_volume"

destination_volume_disk="$(get_disk_number "$destination_volume")"

if [[ "$destination_volume_disk" == "" ]]; then
	fail_gracefully 'Destination Volume Disk not found.'
fi

destination_efi_partition="$(get_efi_partition "$destination_volume_disk")"

echo_log "destination_volume_disk = $destination_volume_disk"
echo_log "destination_efi_partition = $destination_efi_partition"


## Sanity Checks.

if [[ "$source_efi_partition" == "" ]]; then
	fail_gracefully 'EFI source partition not found.'
fi

if [[ "$destination_efi_partition" == "" ]]; then
	fail_gracefully 'EFI destination partition not found.'
fi

if [[ "$source_efi_partition" == "$destination_efi_partition" ]]; then
	fail_gracefully 'EFI source and destination partitions are the same.'
fi

source_efi_partition_split=($source_efi_partition)
if [ "${#source_efi_partition_split[@]}" -gt 1 ]; then
	fail_gracefully 'Multiple EFI source partitions found.'
fi

destination_efi_partition_split=($destination_efi_partition)
if [ "${#destination_efi_partition_split[@]}" -gt 1 ]; then
	fail_gracefully 'Multiple EFI destination partitions found.'
fi


## Mount Targets.

diskutil quiet mount readOnly /dev/$source_efi_partition
if (( $? != 0 )); then
	fail_gracefully 'Mounting EFI source partition failed.'
fi

diskutil quiet mount /dev/$destination_efi_partition
if (( $? != 0 )); then
	fail_gracefully 'Mounting EFI destination partition failed.'
fi

echo_log 'Drives mounted.'
source_efi_mount_point="$(get_disk_mount_point "$source_efi_partition")"
echo_log "source_efi_mount_point = $source_efi_mount_point"

destination_efi_mount_point="$(get_disk_mount_point "$destination_efi_partition")"
echo_log "destination_efi_mount_point = $destination_efi_mount_point"


## Synchronize.

if [[ -n "$dry_mode" ]]; then
	echo_log 'Simulating file synchronization...'
	echo_log 'The following rsync command will be executed with the "--dry-run" option:'
	echo_log "rsync -av --exclude='.*'' \"$source_efi_mount_point/\" \"$destination_efi_mount_point/\""
	echo_log "THE BELOW OUTPUT IS FROM AN RSYNC DRY RUN! NO DATA HAS BEEN MODIFIED!"
	echo '----------------------------------------'
	rsync --dry-run -av --exclude=".*" --delete "$source_efi_mount_point/" "$destination_efi_mount_point/"
	echo '----------------------------------------'
else
	echo_log "Synchronizing files from $source_efi_mount_point/EFI to $destination_efi_mount_point..."
	echo '----------------------------------------'
	rsync -av --exclude=".*" --delete "$source_efi_mount_point/" "$destination_efi_mount_point/"
	echo '----------------------------------------'
fi


## Validate Destination.

echo_log 'Comparing checksums of EFI directories...'
echo_log "Source directory hash:"
echo '----------------------------------------'
source_efi_hash="$(collect_efi_hash "$source_efi_mount_point")"
echo -e "$source_efi_hash"
echo '----------------------------------------'
echo_log "Destination directory hash:"
echo '----------------------------------------'
destination_efi_hash="$(collect_efi_hash "$destination_efi_mount_point")"
echo -e "$destination_efi_hash"
echo '----------------------------------------'

diskutil quiet unmount /dev/$destination_efi_partition
diskutil quiet unmount /dev/$source_efi_partition
echo_log 'EFI partitions unmounted.'

if [[ -z "$dry_mode" ]]; then
	if [[ "$source_efi_hash" == "$destination_efi_hash" ]]; then
		echo_log "Directory hashes match; files copied successfully."
		display_notification 'EFI Clone Script completed successfully.'
	else
		fail_gracefully 'Directory hashes differ; copying failed.' 'EFI copied unsuccessfully; files do not match source.'
	fi
fi

echo_log 'EFI Clone Script completed.'

exit 0
