# EFI Partition Clone Script Utilities

function usage () {
  [ -n "$1" ] && echo -e "$1\n"
  echo "Usage: $0 [-n|--dry-run] [-h|--help] SOURCE DEST"
  echo "  -n, --dry-run  Simulate a clone without actually modifying any files."
  echo "  -h, --help     Display this help."
  echo "  SOURCE         The source volume. This can be the source EFI volume, or a"
  echo "                 sibling volume of the source EFI."
  echo "  DEST           The destination volume. This can be the destination EFI volume,"
  echo "                 or a sibling volume of the destination EFI."
  echo ""
  echo "Example: $0 --dry-run /Volumes/macOS /Volumes/BackUp"
  [ -n "$1" ] && exit 1 || exit 0
}

function echoLog () {
	echo "[`date`] - ${*}"
}

function displayNotification () {
	osascript -e "display notification \"${*}\" with title \"EFI Clone Script\""
}

function failGracefully () {
	echoLog "$1 Exiting."
	displayNotification "${2:-$logMsg} EFI Clone Script failed."
	exit "${3:-1}"
}

function validateParamCount () {
	if [[ "$1" != "$2" ]]; then
		failGracefully "Parameter count of $2 is not supported." 'Unsupported set of parameters received.'
	fi
}

function getDiskNumber () {
	diskutil info "$1" 2>/dev/null | grep 'Part of Whole' | rev | cut -d ' ' -f1 | rev
}

function getCoreStoragePhysicalDiskNumber () {
	diskutil info "$1" | grep 'PV UUID' | rev | cut -d '(' -f1 | cut -d ')' -f2 | rev | cut -d 'k' -f2 | cut -d 's' -f1
}

function getAPFSPhysicalDiskNumber () {
	diskutil apfs list | grep -A 9 "Container $1 " | grep "APFS Physical Store" | rev | cut -d ' ' -f 1 | cut -d 's' -f 2 | cut -d 'k' -f 1 | rev
}

function getEFIVolume () {
	diskutil list | grep "$1s" | grep "EFI" | rev | cut -d ' ' -f 1 | rev
}

function getEFIPartition () {
	local volumeDisk="$1"
	local disk=$volumeDisk
	local EFIPartition="$( getEFIVolume "$disk" )"

	# If we don't find an EFI partition on the disk that was identified by the
	# volume path, we check to see if it is a coreStorage volume and get the disk
	# number from there.
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$( getCoreStoragePhysicalDiskNumber "$volumeDisk" )"
		if [[ "$disk" == "disk" ]]; then
			disk=$volumeDisk
		fi
		EFIPartition="$( getEFIVolume "$disk" )"
	fi

	# If we still don't have an EFI partition then we check to see if the
	# volumeDisk is an APFS volume and find its physical disk.
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$( getAPFSPhysicalDiskNumber "$volumeDisk" )"
		EFIPartition="$( getEFIVolume "$disk" )"
	fi

	echo "$EFIPartition"
}

function getDiskMountPoint () {
	diskutil info "$1" | grep 'Mount Point' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}'
}

function getEFIDirectoryHash () {
	find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum | shasum
}

function logEFIDirectoryHashDetails () {
	find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum
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
	system_profiler SPSoftwareDataType | grep 'Boot Volume' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}'
}

function getCurrentBootEFIVolumeUUID () {
	bdmesg | grep 'SelfDevicePath' | rev | cut -d ')' -f 2 | rev | cut -d ',' -f 3
}

function getDeviceIDfromUUID () {
	diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev
}

function getDiskIDfromUUID () {
	echoLog "$1"
	diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev
}
