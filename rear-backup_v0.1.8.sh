#!/bin/bash
# name          : rear-backup
# desciption    : Create bootable ISO files containing backup tar archiv. Create bootable USB stick from various iso files, mapping storage path via sshfs
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.1.8
# notice        :
# infosource    :
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 Version=0.1.8
 ScriptName=$(basename $0)

 SSHFSUser=user
 SSHFSHost=ip
 BackupFileSuffix="OS"
 OutputDirectoryOverride="true"
 TmpDirectoryOverride="false"			# does not work on debian 12 => recovery error => mktemp:failed to create file via template 'home/rear_tmp/tmp.XXXXXXXXXX: No such file ....
 RearTmpDirOverrideDir="/home/rear_tmp"		# temp dir for gathing tar files
 BackupTargetDirRemoteHost="ReaR_Backups"
 BackupExcludeDir=" $RearTmpDirOverrideDir /mnt /media /home/vbox/VirtualBox_VMs /home/Archiv /home/vdr_recdir /home/.Trash* /var/tmp /var/lib/rear/output "
 RearRecoverTimeout=30

 RearOutputMode=ISO
 RequiredPackets="rear sshfs openssh-client syslinux syslinux-utils pigz locate lshw pv"
 RearOutputImageName="$(hostname)_$(date +%F-%H%M%S)_${BackupFileSuffix}"
 SSHFSMountpoint="/mnt/${SSHFSUser}@$(echo ${SSHFSHost} | tr -d "/")_ReaR"
 RearOutputDir="${SSHFSMountpoint}/${BackupTargetDirRemoteHost}"

 CheckMark="\033[0;32m\xE2\x9C\x94\033[0m"

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###############################################   parser  ##################################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 BackupExcludeDirParsed=$(for i in $BackupExcludeDir ; do echo -n "'$i/*' " ; done)

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		HelpDialog;-h
		ScriptInformation;-i
		CreateISOBackup;-cib
		CreateUSBDrive;-cUSB
		ExternalISOFile;-eISO
		SSHConnectionCheck;-sshcc
		CheckForRequiredPackages;-cfrp
		Monochrome;-m
	"

	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for InputOption in $(echo " $@" | sed 's/ -/\n-/g') ; do
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
			if [[ $InputOption == "$VarValue" ]]; then
				eval $(echo "$VarName"='$InputOption')					# if [[ -n Option1 ]]; then echo "Option1 set";fi
				#eval $(echo "$VarName"="true")
			elif [[ $(echo $InputOption | cut -d "$OptionAllocator" -f1) == "$VarValue" ]]; then
				eval $(echo "$VarName"='$(echo $InputOption | cut -d "$OptionAllocator" -f 2-5000)')
			fi
		done
	done
	IFS=$SAVEIFS

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
script_information () {
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Location:   $(pwd)/$ScriptName\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
}
#------------------------------------------------------------------------------------------------------------

usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -h		=> help dialog \n"
	printf " -cib		=> create ISO Backup\n"
	printf " -cUSB		=> create bootable USB drive\n"
	printf " -eISO		=> external ISO file for -cUSB option (-eISO <file.iso|iso>)\n"
	printf " -sshcc		=> SSH connection check\n"
	printf " -cfrp		=> check for required packages\n"
	printf " -m		=> monochrome output\n"
	printf "\n ${LRed} $1 ${Reset} \n"
	printf "\n"

	# revoke temporary created directories
	output_directory_override -d &> /dev/null

	exit
}
#------------------------------------------------------------------------------------------------------------------------------------------------
load_color_codes () {
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'
	# Use them to print in your required colours:
	# printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
}
#------------------------------------------------------------------------------------------------------------------------------------------------
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w $Packet <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) " -i "Y" InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf "programm error: \e[0;31m missing packets : $MissingPackets\e[0m\n\n"$(tput sgr0)
			exit 1
		fi
	else
		printf " all required packets detected\n"
	fi
	exit
}
#------------------------------------------------------------------------------------------------------------
SSH_connection_check () {

	printf " check sshfs connection\n"
	ssh ${SSHFSUser}@${SSHFSHost} -t exit
	if [[ ! $? == 0 ]]; then
		usage " SSH connection failed"
	else
		printf " SSH connection ${SSHFSUser}@${SSHFSHost} established $CheckMark\n"

		# check sshfs mount process
		printf "\n check sshfs mount process\n"

		mkdir -p "${SSHFSMountpoint}"

		sshfs -o allow_other,follow_symlinks ${SSHFSUser}@${SSHFSHost}: ${SSHFSMountpoint}
		if [[ $? == 0 ]]; then
			printf " SSHFS connection ${SSHFSUser}@${SSHFSHost} established $CheckMark\n"
		else
			umount --force ${SSHFSMountpoint} 	&>/dev/Null
			rmdir "${SSHFSMountpoint}"		&>/dev/null
			usage " sshfs mount error "
		fi

		umount --force ${SSHFSMountpoint}
		rmdir "${SSHFSMountpoint}"
	fi
	exit 1
}
#------------------------------------------------------------------------------------------------------------
output_directory_override () {								# usage: <-e|-d> (enable|disable)

	# create and mount custom output directories
	if [[ $1 == "-e" ]]; then

		# create/mount sshfs remote storage directory
		mkdir -p "${SSHFSMountpoint}"
		sshfs -o allow_other,follow_symlinks ${SSHFSUser}@${SSHFSHost}: ${SSHFSMountpoint}
		if [[ $? == 0 ]]; then
			printf " SSH connection ${SSHFSUser}@${SSHFSHost} established $CheckMark\n"
		else
			SSH_connection_check
		fi

	# delete and unmount custom directories
	elif [[ $1 == "-d" ]]; then

		# unmount and delete directories
		umount --force ${SSHFSMountpoint}
		rmdir ${SSHFSMountpoint}
	fi
}
#------------------------------------------------------------------------------------------------------------
tmp_directory_override () {								# usage: <-e|-d> (enable|disable)

	# create custom tmp directories
	if [[ $1 == "-e" ]]; then

		# create rear TMPDIR
		mkdir -p $RearTmpDirOverrideDir

	# delete custom tmp directories
	elif [[ $1 == "-d" ]]; then

		# delete rear TMPDIR
		rm -r $RearTmpDirOverrideDir
	fi
}
#------------------------------------------------------------------------------------------------------------
WriteRearConfigISO () {

	echo '
		OUTPUT=ISO
		ISO_DIR='${RearOutputDir}'
		ISO_PREFIX="'$RearOutputImageName'"
		OUTPUT_URL=null
		BACKUP=NETFS
		BACKUP_URL="iso:///backup"

	' | grep -v "^#" > /etc/rear/local.conf
}
#------------------------------------------------------------------------------------------------------------
WriteRearConfigRAW () {

	# TODO create a bootable usb stick directly from Rear
	# issue : Raw output, used to create an image file, does not support including backup.tar archiv
	# you have to create an loop device, and use this loop device for OUTPUT=USB://path''/to/loopdevice to include backup tar archiv
	#
	# https://github.com/rear/rear/issues/2581

	echo '
		OUTPUT=RAW
		RAW_DIR='${RearOutputDir}'
		OUTPUT_URL=null

		RAWDISK_IMAGE_NAME="'$RearOutputImageName'"
		RAWDISK_IMAGE_COMPRESSION_COMMAND='\''gzip'\''
		RAWDISK_FAT_VOLUME_LABEL='\''RESCUE SYS'\''
		RAWDISK_GPT_PARTITION_NAME='\'''$RearOutputImageName' Rescue System'\''

	' | grep -v "^#" >> /etc/rear/local.conf
}
#------------------------------------------------------------------------------------------------------------
WriteRearConfigAdditional () {

	echo '
		# increase data compression by using pigs instead of gzip
		BACKUP_PROG_COMPRESS_OPTIONS=( --use-compress-program=pigz )
		REQUIRED_PROGS+=( pigz )

		# input timeout for autorecover
		USER_INPUT_TIMEOUT='$RearRecoverTimeout'

		# resize partitions
		AUTORESIZE_PARTITIONS=true
#		AUTORESIZE_PARTITIONS=( /dev/sda3 )
#		AUTORESIZE_EXCLUDE_PARTITIONS=( /dev/sda2 )

		# exclude directories from backup
		BACKUP_PROG_EXCLUDE=( '$BackupExcludeDirParsed' )

		# change mkisofs to xorriso to avoid file size limits
#		ISO_MKISOFS_BIN=xorriso
#		MKISOFS_BIN=xorriso
#		USE_XORRISO=true

		# disable iso filesize limit => 0 (default 2 GB ISO_FILE_SIZE_LIMIT=2147483648)
		ISO_FILE_SIZE_LIMIT=0

	' | grep -v "^#" >> /etc/rear/local.conf

	# check for tmp directory override
	if [[ $TmpDirectoryOverride == true ]]; then
		echo '		export TMPDIR='$RearTmpDirOverrideDir' ' >> /etc/rear/local.conf
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_ISO_Backup () {

	# create backup directory on ssh host
	mkdir -p "${RearOutputDir}"

	# backup existing ReaR configuration and setup temporary ReaR configuration
	cp /etc/rear/local.conf /etc/rear/local.conf_bak

	# create rear configfile in /etc/rear/local.conf
	if   [[ $RearOutputMode == "ISO" ]]; then
		WriteRearConfigISO
	elif [[ $RearOutputMode == "RAW" ]]; then
		WriteRearConfigRAW
	fi

	WriteRearConfigAdditional

	# start ReaR backup
	rear -v mkbackup

	# restore ReaR configuration
	mv /etc/rear/local.conf_bak /etc/rear/local.conf
}
#------------------------------------------------------------------------------------------------------------------------------------------------
check_ISO_file () {									# usage: check_ISO_file <isofile.iso>

	# check for empty iso file option
	if [[ $1 == "-eISO" ]]; then
		usage "no ISO file specefied"
	fi

	# check ISO file - absolute path input
	if [[ -f $1 ]]; then
		ISOFileAbsolutePath=$1
	else
		# check ISO file - filename input | updatedb/locate for quick image location ( file cmd causes error if absolutepath is not defined )
		updatedb
		ISOFile=$(locate -b "$1" | grep "\.iso$")

		# check for more than one matched ISO file, print selection for various
		ISOFileAbsolutePath=$ISOFile
		if [[ $(grep -c . <<< $ISOFile) -gt 1 ]]; then
			ISOImageList=$(echo "$ISOFile" | nl | sed 's/^ */ /g')
			ISOImageListCount=$(echo "$ISOFile" | grep -c .)
			request_loop5 () {
				printf " Various ISO Images detected, select one image: \n"
				printf "$ISOImageList\n"
				read -s -n 1 ISOImageSelection
				if [[ -z $( grep [[:digit:]] <<< $ISOImageSelection) ]] || [[ $ISOImageSelection -gt $ISOImageListCount ]]; then
					printf " ${LRed}invalid number: $ISOImageSelection ${Reset}\n\n"
					request_loop5
				fi
			}
			request_loop5
			ISOFileAbsolutePath=$(echo "$ISOImageList" | grep "^ $ISOImageSelection" | awk -F " " '{printf $2}')
		fi
	fi

	# check for existing file
	if [[ -f $ISOFileAbsolutePath ]]; then
		printf "\n image exists $CheckMark ($ISOFileAbsolutePath)\n"
	else
		usage " file not found: $1"
	fi

	# get iso file specs
	FileProperties=$(file $ISOFileAbsolutePath)

	# check ISO filesystem
	if   [[ -n $(grep "ISO 9660" <<< $FileProperties) ]]; then
		printf " ISO filesystem $CheckMark\n"
		ISOHybrid=false
	elif [[ -n $(grep " DOS/MBR boot sector" <<< $FileProperties) ]]; then
		printf " Hybrid filesystem $CheckMark\n"
		ISOHybrid=true
	else
		usage "invalid ISO file: $(printf "$(echo -e " $FileProperties" | sed 's/iso:/iso \\n type:\\t\\t   '/)")"
	fi

	# check for bootable ISO
	if [[ -z $(grep "bootable" <<< $FileProperties) ]]; then
		request_loop4 () {
			Request=
			printf " ${LYellow}non bootable ISO file: ${Reset} $ISOFileAbsolutePath\n"
			read -n1 -e -p " Are you sure to use this image (y/N)? " Request
			if   [[ "$Request" == [yY] ]]; then
				printf "\033[F\033[F \n non bootable ISO image accepted $CheckMark       \n"
			elif [[ "$Request" == [nN]  ]]; then
				printf " USB drive creation process canceled\n"
				exit 1
			else
				request_loop4
			fi
			printf ""
		}
		request_loop4
	else
		printf " bootable ISO image $CheckMark\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
detect_and_select_usb_drives () {

	DetectUSBDrivesResultFile=/tmp/.usbdrives
	DeviceListRAW=$(ls /dev/sd{a..z} 2> /dev/null)
	DeviceListInfoRAW=$(lshw -class disk | sed 's/removable/removeable/g') # sed corrects lshw misspelling
	DeviceListOS=$(df -h | grep -v "/media/")

	# write detect usb devices to file => $DetectUSBDrivesResultFile
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $DeviceListRAW ; do
		if [[ -n $( grep $i <<< "$DeviceListOS") ]]; then
			printf "Systemdevice detected: $i \n\n"
		else
			# get USB drive vars
			DeviceInfo=$( grep -m1 -A5 -B5 "$i" <<< "$DeviceListInfoRAW")

			DeviceSize=$(awk -F "size:" '{printf $2 $3 }' <<< "$DeviceInfo")
			DeviceProduct=$(awk -F "product:" '{printf $2 $3 }' <<< "$DeviceInfo")
			DeviceVendor=$(awk -F "vendor:" '{printf $2 $3 }' <<< "$DeviceInfo")
			DeviceCapability=$(awk -F "capabilities:" '{printf $2 $3 }' <<< "$DeviceInfo")

			# set unknown var for unset vars
			DeviceSize=${DeviceSize:- unknown size}
			DeviceProduct=${DeviceProduct:-unknown product}
			DeviceVendor=${DeviceVendor:-unknown Vendor}
			DeviceCapability=${DeviceCapability:-unknown capability}

			printf "%-20s %-8s %-10s %-18s %-10s\n" "USB drive detected:" "$i" "$DeviceProduct" "$DeviceSize" "$DeviceCapability"
		fi
	done | grep USB | nl | sed 's/^ */ /g' > $DetectUSBDrivesResultFile
	IFS=$SAVEIFS

	# select USB drive if more than one usb drive is detected
	USBDriveChoise=1
	DetectedUSBDeviceCount=$( grep -c . $DetectUSBDrivesResultFile)
	if   [[ $DetectedUSBDeviceCount == 0 ]]; then
		usage " no usb drive found"
	elif [[ $DetectedUSBDeviceCount -gt 1 ]]; then
		request_loop () {
			printf "\n select USB drive: \n" 
			cat $DetectUSBDrivesResultFile
			read -s -n 1 USBDriveChoise
			if [[ -z $( grep [[:digit:]] <<< $USBDriveChoise) ]] || [[ $USBDriveChoise -gt $DetectedUSBDeviceCount ]]; then
				printf " invalid number: $USBDriveChoise \n"
				request_loop
			fi
		}
		request_loop
	fi

	# get selected USB device path
	SelectedUSBDrive=$(grep "^ $USBDriveChoise" $DetectUSBDrivesResultFile) 
	USBTargetDevicePath=$( awk -F " " '{printf $5}' <<< "$SelectedUSBDrive")

	printf "\n$(sed 's/detected/selected/' <<< $SelectedUSBDrive)\n"

	# final check for correct device path
	request_loop2 () {
		Request=
		printf "\n${Red} ALL DATA ON THIS DEVICE WILL BE LOST !${Reset} Really use this drive (y/N)? "
		read -n1 -e Request
		if   [[ "$Request" == [yY] ]]; then
			printf ""
		elif [[ "$Request" == [nN] ]]; then
			printf " USB drive creation process canceled\n"
			exit 1
		else
			request_loop2
		fi
		printf ""
	}
	request_loop2
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_USB_drive_from_ISO () {

	# unmount USB drive if mounted
	umount --force ${USBTargetDevicePath}* 2> /dev/null

	# format USB drive with vFAT filesystem
	printf "\n format USB drive (${USBTargetDevicePath}) with vFAT filesystem\n"
	mkfs -t vfat -I ${USBTargetDevicePath}

	# create iso hybrid filesystem for iso 9660
	if   [[ $ISOHybrid == false ]]; then

		# copy source ISO
		printf "\n copy ISO file for header update"
		cp ${ISOFileAbsolutePath} ${ISOFileAbsolutePath}-isohybrid

		# prepeare image header for blockdevice copy
		printf "\n change ISO header"
		isohybrid ${ISOFileAbsolutePath}-isohybrid --entry 4 --type 0x1c

		# write ISO to USB drive
		ISO2USBSourcefile="${ISOFileAbsolutePath}-isohybrid"
		write_ISO_to_USB

		# delete Isohybrid image
		rm ${ISOFileAbsolutePath}-isohybrid

	elif [[ $ISOHybrid == true ]]; then
		# write ISO to USB drive
		ISO2USBSourcefile=${ISOFileAbsolutePath}
		write_ISO_to_USB
	fi
}
#------------------------------------------------------------------------------------------------------------
write_ISO_to_USB () {

	# write ISO file to USB drive
	printf "\n write ISO file to USB drive\n"
	dd if=${ISO2USBSourcefile} | pv ${ISO2USBSourcefile} | dd of=${USBTargetDevicePath} status=none conv=fdatasync oflag=sync bs=2M 
}
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then
		printf "\n"
		script_information
		printf "\n"
		exit
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------

	# option conflict check
	if [[ -n $CreateISOBackup  && -n $ExternalISOFile ]]; then
		usage " option conflict -eISO -cib ( choose one )"
	fi

#------------------------------------------------------------------------------------------------------------

	# check for root permission
	if [ ! "$(whoami)" = "root" ]; then printf "\nAre You Root ?\n\n";exit 1;fi

#------------------------------------------------------------------------------------------------------------

	if [[ -n $CheckForRequiredPackages ]]; then
		check_for_required_packages
	fi

#------------------------------------------------------------------------------------------------------------

	if [[ -n $SSHConnectionCheck ]]; then
		SSH_connection_check
	fi

#------------------------------------------------------------------------------------------------------------

	# create ReaR ISO backup
	if   [[ -n $CreateISOBackup ]]; then

		# create rear TMPDIR 
		if [[ $TmpDirectoryOverride == true ]]; then
			tmp_directory_override -e
		fi

		# create local mountpoint, mount ssh remote host and create iso backup target dir, create rear TMPDIR
		if [[ $OutputDirectoryOverride == true ]]; then
			output_directory_override -e
		fi

		create_ISO_Backup

		# set source iso for USB creation
		SourceISO="${RearOutputDir}/${RearOutputImageName}.iso"
	fi

#------------------------------------------------------------------------------------------------------------

	# check for USB creation or external ISO file
	if [[ -n $CreateUSBDrive ]] || [[ -n $ExternalISOFile ]]; then

		if [[ -n $ExternalISOFile ]]; then
			SourceISO="$ExternalISOFile"
		fi

		# check ISO file
		check_ISO_file "$SourceISO"

		# detect and select usb drives
		detect_and_select_usb_drives

		#TODO check if USB drive size is larger than ISO image file size

		# create bootable usb drive from ISO file
		create_USB_drive_from_ISO
	fi

#------------------------------------------------------------------------------------------------------------

	# revoke temporary created directories
	if [[ $OutputDirectoryOverride == true ]]; then
		output_directory_override -d &> /dev/null
		tmp_directory_override    -d &> /dev/null -d &> /dev/null
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
# TODO add  create config dialog, export script configs to external file

# 0.1.8 => functionname corrected (241) // add ScriptInformation var (55) // ISO_File_Size_Limit disabled (281)
