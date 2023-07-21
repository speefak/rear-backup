#!/bin/bash
# name          : rear-backup
# desciption    : create temporary connects and paths for rear backup
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.1.0
# notice        :
# infosource    :
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 Version=0.1.0
 ScriptName=$(basename $0)

 SSHFSUser=speefak
 SSHFSHost=192.168.1.X
 BackupTargetDirRemoteHost="ISO_Backups"
 BackupFileSuffix="entire_disk"

 SSHFSMountpoint="/mnt/${SSHFSUser}@$(echo ${SSHFSHost} | tr -d "/")_ReaR"
 RearOutputDir="${SSHFSMountpoint}/${BackupTargetDirRemoteHost}"

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

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
        printf " -h             => help dialog \n"
        printf  "\e[0;31m\n $1\e[0m\n"
        printf "\n"
        exit
}

#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

        # check for script information
        if [[ $1 == "-i" ]]; then
                printf "\n"
                script_information
                printf "\n"
        fi

#------------------------------------------------------------------------------------------------------------

        # check for root permission
        if [ ! "$(whoami)" = "root" ]; then printf "\nAre You Root ?\n\n";exit 1;fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------
        # create local mountpoint, mount ssh remote host and create iso backup target dir
        mkdir -p "${SSHFSMountpoint}"
        sshfs -o allow_other,follow_symlinks ${SSHFSUser}@${SSHFSHost}: ${SSHFSMountpoint}
        mkdir -p "${RearOutputDir}"

#-------------------------------------------------------------------------------------------------------------

        # backup existing ReaR configuration and setup temporary ReaR configuration

        cp /etc/rear/local.conf /etc/rear/local.conf_bak

        echo '

                OUTPUT=ISO
                ISO_DIR='${RearOutputDir}'
                OUTPUT_URL=null
                BACKUP=NETFS
                BACKUP_URL="iso:///backup"

                BACKUP_PROG_COMPRESS_OPTIONS=( --use-compress-program=pigz )
                REQUIRED_PROGS+=( pigz )

		USER_INPUT_TIMEOUT=3

                AUTORESIZE_PARTITIONS=true

        ' > /etc/rear/local.conf

#------------------------------------------------------------------------------------------------------------

        # start ReaR backup
        rear -v mkbackup

#------------------------------------------------------------------------------------------------------------

        # restore ReaR configuration
        mv /etc/rear/local.conf_bak /etc/rear/local.conf

#------------------------------------------------------------------------------------------------------------

        # rename iso backup file
        cd ${RearOutputDir}
        mv "$(ls | grep -w rear-$(hostname).iso)" "$(hostname)_$(date +%F-%H%M%S)_${BackupFileSuffix}.iso"
        cd -
	printf "\n final image stored in ${RearOutputDir}/$(hostname)_$(date +%F-%H%M%S)_${BackupFileSuffix}.iso \n"

#------------------------------------------------------------------------------------------------------------

        # unmount and delete directories
        umount ${SSHFSMountpoint}
        rmdir ${SSHFSMountpoint}

#------------------------------------------------------------------------------------------------------------

exit 0

