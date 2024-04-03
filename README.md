I missed in the ReaR ( Relax and Recover ) programm/script suite some very useful functions like creation of ISO hybridimages for USB stick use, USB stick backup does not contain bootable systems and is not networkshare compatible, ReaR directories are located in /tmp and /var - for very large backups often too small diskspace.

This script adds the features listet above to ReaR.

# rear-backup
Create bootable ISO files, containing backup tar archiv. Create bootable USB stick from various iso files

      Usage: rear-backup_v0.1.6.sh <options> 
       -h		=> help dialog 
       -cib		=> create ISO Backup
       -cUSB        => create bootable USB drive
       -eISO	=> external ISO file for -cUSB option (-eISO <file.iso|iso>)
       -sshcc	=> SSH connection check
       -cfrp	=> check for required packages
       -m		=> monochrome output


