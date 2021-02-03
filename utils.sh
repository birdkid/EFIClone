# EFI Partition Clone Script Utilities

function usage() {
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

function echo_log() {
	echo "[`date`] - ${*}"
}

function display_notification() {
	osascript -e "display notification \"${*}\" with title \"EFI Clone Script\""
}

function fail_gracefully() {
	echo_log "$1 Exiting."
	display_notification "${2:-$logMsg} EFI Clone Script failed."
	exit "${3:-1}"
}

function validate_param_count() {
	if [[ "$1" != "$2" ]]; then
		fail_gracefully "Parameter count of $2 is not supported." 'Unsupported set of parameters received.'
	fi
}

function get_disk_number() {
	diskutil info "$1" 2>/dev/null | grep 'Part of Whole' | rev | cut -d ' ' -f1 | rev
}

function get_core_storage_physical_disk_number() {
	diskutil info "$1" | grep 'PV UUID' | rev | cut -d '(' -f1 | cut -d ')' -f2 | rev | cut -d 'k' -f2 | cut -d 's' -f1
}

function get_apfs_physical_disk_number() {
	diskutil apfs list | grep -A 9 "Container $1 " | grep "APFS Physical Store" | rev | cut -d ' ' -f 1 | cut -d 's' -f 2 | cut -d 'k' -f 1 | rev
}

function get_efi_volume() {
	diskutil list | grep "$1s" | grep "EFI" | rev | cut -d ' ' -f 1 | rev
}

function get_efi_partition() {
	local volume_disk="$1"
	local disk=$volume_disk
	local EFIPartition="$(get_efi_volume "$disk")"

	# If we don't find an EFI partition on the disk that was identified by the
	# volume path, we check to see if it is a coreStorage volume and get the disk
	# number from there.
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$(get_core_storage_physical_disk_number "$volume_disk")"
		if [[ "$disk" == "disk" ]]; then
			disk=$volume_disk
		fi
		EFIPartition="$(get_efi_volume "$disk")"
	fi

	# If we still don't have an EFI partition then we check to see if the
	# volume_disk is an APFS volume and find its physical disk.
	if [[ "$EFIPartition" == "" ]]; then
		disk='disk'"$(get_apfs_physical_disk_number "$volume_disk")"
		EFIPartition="$(get_efi_volume "$disk")"
	fi

	echo "$EFIPartition"
}

function get_disk_mount_point() {
	diskutil info "$1" | grep 'Mount Point' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}'
}

function get_efi_directory_hash() {
	find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum | shasum
}

function log_efi_directory_hash_details() {
	find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum
}

function collect_efi_hash() {
	local efi_mount_point="$1"
	pushd "$efi_mount_point/" > /dev/null
	EFIHash="$(get_efi_directory_hash "$efi_mount_point/EFI")"
	log_efi_directory_hash_details "$efi_mount_point"
	popd > /dev/null
	echo "$EFIHash"
}

function get_system_boot_volume_name() {
	system_profiler SPSoftwareDataType | grep 'Boot Volume' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}'
}

function get_current_boot_efi_volume_uuid() {
	bdmesg | grep 'SelfDevicePath' | rev | cut -d ')' -f 2 | rev | cut -d ',' -f 3
}

function get_device_id_from_uuid() {
	diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev
}

function get_disk_id_from_uuid() {
	echo_log "$1"
	diskutil info "$1" | grep 'Device Identifier' | rev | cut -d ' ' -f 1 | rev
}
