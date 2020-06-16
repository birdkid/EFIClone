#!/bin/bash
# EFI Partition Clone Script
# Created by Ted Howe (c) 2018 | tedhowe@burke-howe.com | wombat94 on GitHub   | wombat94 on TonyMacx86
# Modified by kobaltcore 2019  | cobaltcore@yandex.com  | kobaltkore on GitHub | byteminer on TonyMacx86 forums

# This script is designed to be a "post-flight" script run automatically by CCC at the end of a
# clone task. It will copy the contents of the source drive's EFI partition to the destination drive's EFI
# partition. It will COMPLETELY DELETE and replace all data on the destination EFI partition.

# THIS SCRIPT MODIFIES DATA AND AS SUCH CAN CAUSE DATA LOSS!
# Use this at your own risk. We've tried to make it as safe as possible, but nobody's perfect.


### START USER VARIABLES ###

# Whether to run in LIVE or DEBUG mode. If this is "Y", this script will operate in dry-run mode, simply logging
# what it would do without actually doing it.
# Setting this to any other values (preferably "N") will switch to live mode, in which the operations will be executed.
TEST_SWITCH="Y"

# The location of the log file. Since the root partition is read-only in Catalina and higher
# we write to the "Shared" folder instead.
LOG_FILE="/Users/Shared/EFIClone.log"

### STOP USER VARIABLES ###


### Method Definitions ###
if [[ -f "$LOG_FILE" ]]; then
	rm $LOG_FILE
fi

function writeTolog () {
	echo "[`date`] - ${*}" >> ${LOG_FILE}
}

function displayNotification () {
	osascript -e "display notification \"${*}\" with title \"EFI Clone Script\""
}

function failGracefully () {
	writeTolog "$1"
	displayNotification "${2:-$logMsg}"
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

function getDiskMountPoint () {
	echo "$( diskutil info "$1" | grep 'Mount Point' | rev | cut -d ':' -f 1 | rev | awk '{$1=$1;print}' )"
}

function getEFIDirectoryHash () {
	echo "$( find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum | shasum )"
}

function logEFIDirectoryHashDetails () {
	echo "$( find -s . -not -path '*/\.*' -type f \( ! -iname ".*" \) -print0 | xargs -0 shasum )" >> ${LOG_FILE}
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


### Start Script ###

writeTolog "***** EFI Clone Script Started *****"
writeTolog "Running $0"

# Determine which disk clone application called the script (based on number of parameters)
# - log details
# - set up initial parameters
# - if possible do app-specific sanity checks in order to exit without taking action if necessary
if [[ "$#" == "2" ]]; then
	writeTolog "Called From Shell with the following parameters:"
	writeTolog "1: Source Path = $1"
	writeTolog "2: Destination Path = $2"

	sourceVolume=$1
	destinationVolume=$2
elif [[ "$#" == "4" ]]; then
	writeTolog "Called From Carbon Copy Cloner with the following parameters:"
	writeTolog "1: Source Path = $1"
	writeTolog "2: Destination Path = $2"
	writeTolog "3: CCC Exit Status = $3"
	writeTolog "4: Disk image file path = $4"

	if [[ "$3" == "0" ]]; then
		writeTolog "CCC completed with success, the EFI Clone Script will run"
	else
		failGracefully 'CCC did not exit with success, the EFI Clone Script will not run' 'CCC Task failed, EFI Clone Script did not run'
	fi

	if [[ "$4" == "" ]]; then
		writeTolog "CCC clone was not to a disk image. the EFI Clone Script will run"
	else
		failGracefully 'CCC Clone destination was a disk image file. The EFI Clone Script will not run' 'CCC Clone destination was a disk image. Clone script did not run.'
	fi

	sourceVolume=$1
	destinationVolume=$2
elif [[ "$#" == "6" ]]; then
	writeTolog "Called From SuperDuper with the following parameters:"
	writeTolog "1: Source Disk Name = $1"
	writeTolog "2: Source Mount Path = $2"
	writeTolog "3: Destination Disk Name = $3"
	writeTolog "4: Destination Mount Path = $4"
	writeTolog "5: SuperDuper! Backup Script Used = $5"
	writeTolog "6: Unused parameter 6 = $6"

	sourceVolume=$2
	destinationVolume=$4
else
	echo "$# parameters were passed in. This is an unsupported number of parameters. Exiting now"
	failGracefully "$# parameters were passed in. This is an unsupported number of parameters. Exiting now" 'Unsupported set of parameters passed in. EFI Clone script did not run!'
fi

writeTolog "sourceVolume = $sourceVolume"


### Figure out source target ###

sourceVolumeDisk="$( getDiskNumber "$sourceVolume" )"

# If we can't figure out the path, we're probably running on Mojave or later, where CCC creates a temporary mount point
# We use the help of "df" to output the volume of that mount point, afterwards it's business as usual
if [[ "$sourceVolumeDisk" == "" ]]; then
	sourceVolume=$( df "$sourceVolume" | grep /dev | cut -d ' ' -f 1 | cut -d '@' -f 2 )
	sourceVolumeDisk="$( getDiskNumber "$sourceVolume" )"
fi

# If it's still empty, we got passed an invalid path, so we exit
if [[ "$sourceVolumeDisk" == "" ]]; then
	failGracefully 'sourceVolumeDisk could not be determined, script exiting.' 'No sourceVolumeDisk found. EFI Clone Script did not run!'
fi

writeTolog "sourceVolumeDisk = $sourceVolumeDisk"

writeTolog "destinationVolume = $destinationVolume"

destinationVolumeDisk="$( getDiskNumber "$destinationVolume" )"

writeTolog "destinationVolumeDisk = $destinationVolumeDisk"
sourceDisk=$sourceVolumeDisk
sourceEFIPartition="$( getEFIVolume "$sourceDisk" )"

# If we don't find an EFI partition on the disk that was identified by the volume path
# we check to see if it is a coreStorage volume and get the disk number from there
if [[ "$sourceEFIPartition" == "" ]]; then
	sourceDisk=""
	sourceDisk=disk"$( getCoreStoragePhysicalDiskNumber "$sourceVolumeDisk" )"
	if [[ "$sourceDisk" == "disk" ]]; then
		sourceDisk=$sourceVolumeDisk
	fi
	sourceEFIPartition="$( getEFIVolume "$sourceDisk" )"
fi

# If we still don't have an EFI partition then we check to see if the sourceVolumeDisk is an APFS
# volume and find its physical disk
if [[ "$sourceEFIPartition" == "" ]]; then
	sourceDisk=""
	sourceDisk=disk"$( getAPFSPhysicalDiskNumber "$sourceVolumeDisk" )"
	sourceEFIPartition="$( getEFIVolume "$sourceDisk" )"
fi

writeTolog "sourceEFIPartition = $sourceEFIPartition"


### Figure out destination target ###

destinationDisk=$destinationVolumeDisk
destinationEFIPartition="$( getEFIVolume "$destinationDisk" )"

# If we don't find an EFI partition on the disk that was identified by the volume path
# we check to see if it is a coreStorage volume and get the disk number from there
if [[ "$destinationEFIPartition" == "" ]]; then
	destinationDisk=""
	destinationDisk=disk"$( getCoreStoragePhysicalDiskNumber "$destinationVolumeDisk" )"
	if [[ "$destinationDisk" == "disk" ]];	then
		destinationDisk=$destinationVolumeDisk
	fi
	destinationEFIPartition="$( getEFIVolume "$destinationDisk" )"
fi

# If we still don't have an EFI partition then we check to see if the destinationVolumeDisk is an APFS
# volume and find its physical disk
if [[ "$destinationEFIPartition" == "" ]]; then
	destinationDisk=""
	destinationDisk=disk"$( getAPFSPhysicalDiskNumber "$destinationVolumeDisk" )"
	destinationEFIPartition="$( getEFIVolume "$destinationDisk" )"
fi

writeTolog "destinationEFIPartition = $destinationEFIPartition"


### Sanity checks ###

if [[ "$efiBootPartitionDisk" == "$destinationDisk" ]]; then
	failGracefully 'Destination disk is the current EFI partition that was used to boot the computer, script exiting.' 'No source EFI Partition found. EFI Clone Script did not run!'
fi

if [[ "$sourceEFIPartition" == "" ]]; then
	failGracefully 'No SourceEFIPartition Found, script exiting.' 'No source EFI Partition found. EFI Clone Script did not run!'
fi

if [[ "$destinationEFIPartition" == "" ]]; then
	failGracefully 'No DestinationEFIPartition Found, script exiting.' 'No destination EFI Partition found. EFI Clone Script did not run!'
fi

if [[ "$sourceEFIPartition" == "$destinationEFIPartition" ]]; then
	failGracefully 'Source and Destination EFI Partitions are the same. Script exiting.' 'Source and Destination EFI partitions are the same. EFI Clone Script did not run!'
fi

sourceEFIPartitionSplit=($sourceEFIPartition)
if [ "${#sourceEFIPartitionSplit[@]}" -gt 1 ]; then
	failGracefully 'More than one source partition. Script exiting.' 'More than one source partition. EFI Clone Script did not run!'
fi

destinationEFIPartitionSplit=($destinationEFIPartition)
if [ "${#destinationEFIPartitionSplit[@]}" -gt 1 ]; then
	failGracefully 'More than one destination partition. Script exiting.' 'More than one destination partition. EFI Clone Script did not run!'
fi

### Mount the targets ###

diskutil mount /dev/$sourceEFIPartition
diskutil mount /dev/$destinationEFIPartition
writeTolog "Drives mounted"
sourceEFIMountPoint="$( getDiskMountPoint "$sourceEFIPartition" )"
writeTolog "sourceEFIMountPoint = $sourceEFIMountPoint"

destinationEFIMountPoint="$( getDiskMountPoint "$destinationEFIPartition" )"
writeTolog "destinationEFIMountPoint = $destinationEFIMountPoint"


### Execute the synchronization ###

if [[ "$TEST_SWITCH" == "Y" ]]; then
	writeTolog "********* Test simulation - file delete/copy would happen here. "
	writeTolog "rsync command will be executed with the --dry-run option"
	writeTolog "rsync command calculated is..."
	writeTolog "rsync -av --exclude='.*'' "$sourceEFIMountPoint/" "$destinationEFIMountPoint/""
	writeTolog "THE BELOW OUTPUT IS FROM AN RSYNC DRY RUN! NO DATA HAS BEEN MODIFIED!"
	writeTolog "----------------------------------------"
	rsync --dry-run -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/" >> ${LOG_FILE}
	writeTolog "----------------------------------------"
	writeTolog "********* Test Simulation - end of file delete/copy section."
else
	writeTolog "Synchronizing all files with rsync --delete option"
	writeTolog "from $sourceEFIMountPoint/EFI to $destinationEFIMountPoint. Details follow..."
	writeTolog "----------------------------------------"
	rsync -av --exclude=".*" --delete "$sourceEFIMountPoint/" "$destinationEFIMountPoint/" >> ${LOG_FILE}
	writeTolog "----------------------------------------"
	writeTolog "Contents of Source EFI Partition copied to Destination EFI Partition"
fi

writeTolog "Comparing the checksums of the EFI directories on the source and destination partitions"
pushd "$sourceEFIMountPoint/"
sourceEFIHash="$( getEFIDirectoryHash "$sourceEFIMountPoint/EFI" )"
temp="$( logEFIDirectoryHashDetails "$sourceEFIMountPoint" )"
popd
pushd "$destinationEFIMountPoint/"
destinationEFIHash="$( getEFIDirectoryHash "$destinationEFIMountPoint/EFI" )"
temp="$( logEFIDirectoryHashDetails "$sourceEFIMountPoint" )"
popd
writeTolog "Source directory hash: $sourceEFIHash"
writeTolog "Destination directory hash: $destinationEFIHash"

diskutil unmount /dev/$destinationEFIPartition
diskutil unmount /dev/$sourceEFIPartition
writeTolog "EFI Partitions Unmounted"

if [[ "$TEST_SWITCH" != "Y" ]]; then
	if [[ "$sourceEFIHash" == "$destinationEFIHash" ]]; then
		writeTolog "Directory hashes match! file copy successful"
		displayNotification 'EFI Clone Script completed successfully.'
	else
		failGracefully 'Directory hashes differ! file copy unsuccessful' 'EFI Clone failed - destionation data did not match source after copy.'
	fi
fi

writeTolog "EFI Clone Script completed"
