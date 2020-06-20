#!/bin/bash
# EFI Partition Clone Script Utilities

function writeTolog () {
	echo "[`date`] - ${*}" >> ${LOG_FILE}
}

function displayNotification () {
	osascript -e "display notification \"${*}\" with title \"EFI Clone Script\""
}

function failGracefully () {
	writeTolog "$1 Exiting."
	displayNotification "${2:-$logMsg} EFI Clone Script failed."
	exit "${3:-1}"
}

function getDiskNumber () {
	echo "$( diskutil info "$1" | grep 'Part of Whole' | rev | cut -d ' ' -f1 | rev )"
}

function getCoreStoragePhysicalDiskNumber () {
	echo "$( diskutil info "$1" | grep 'PV UUID' | rev | cut -d '(' -f1 | cut -d ')' -f2 | rev | cut -d 'k' -f2 | cut -d 's' -f1 )"
}

function getAPFSPhysicalDiskNumber () {
	echo "$( diskutil apfs list | grep -A 9 "Container $1 " | grep "APFS Physical Store" | rev | cut -d ' ' -f 1 | cut -d 's' -f 2 | cut -d 'k' -f 1 )"
}

function getEFIVolume () {
	echo "$( diskutil list | grep "$1s" | grep "EFI" | rev | cut -d ' ' -f 1 | rev )"
}

function getEFIPartition () {
	local volumeDisk="$1"
	local disk=$volumeDisk
	local EFIPartition="$( getEFIVolume "$disk" )"

	# If we don't find an EFI partition on the disk that was identified by the volume path
	# we check to see if it is a coreStorage volume and get the disk number from there
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$( getCoreStoragePhysicalDiskNumber "$volumeDisk" )"
		if [[ "$disk" == "disk" ]]; then
			disk=$volumeDisk
		fi
		EFIPartition="$( getEFIVolume "$disk" )"
	fi

	# If we still don't have an EFI partition then we check to see if the volumeDisk is an APFS
	# volume and find its physical disk
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$( getAPFSPhysicalDiskNumber "$volumeDisk" )"
		EFIPartition="$( getEFIVolume "$disk" )"
	fi

	echo "$EFIPartition"
}

function getDiskMountPoint () {
	echo "$( diskutil info "$1" | grep 'Mount Point' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}' )"
}

function getEFIDirectoryHash () {
	echo "$( find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum | shasum )"
}

function logEFIDirectoryHashDetails () {
	echo "$( find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum )" >> ${LOG_FILE}
}

function collectEFIHash () {
	local EFIMountPoint="$1"
	pushd "$EFIMountPoint/" > /dev/null
	EFIHash="$( getEFIDirectoryHash "$EFIMountPoint/EFI" )"
	logEFIDirectoryHashDetails "$EFIMountPoint"
	popd > /dev/null
	echo "$EFIHash"
}

function getSystemBootVolumeName () {
	echo "$( system_profiler SPSoftwareDataType | grep 'Boot Volume' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}' )"
}

function getCurrentBootEFIVolumeUUID () {
	echo "$( bdmesg | grep 'SelfDevicePath' | rev | cut -d ')' -f 2 | rev | cut -d ',' -f 3 )"
}

function getDeviceIDfromUUID () {
	echo "$( diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev )"
}

function getDiskIDfromUUID () {
	writeTolog "$1"
	echo "$( diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev )"
}
