# EFI Partition Clone Script Post-Flight Settings

# Whether to run in LIVE or DEBUG mode. If this is "Y", this script will operate in dry-run mode, simply logging
# what it would do without actually doing it.
# Setting this to any other values (preferably "N") will switch to live mode, in which the operations will be executed.
TEST_SWITCH='Y'

# The location of the log file. Since the root partition is read-only in Catalina and higher
# we write to the "Shared" folder instead.
LOG_FILE='/Users/Shared/EFIClone.log'
