#!/bin/bash
# name          : df_mod.sh
# desciption    : show differing FS usage, debian 8|9|10|11  SFOS 3.X
# autor         : speefak (itoss@gmx.de)
# licence       : (CC) BY-NC-SA
  VERSION=2.1.9
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 ConfigFile=$HOME/.dff.cfg
 LANDevice=$(ip route | grep default | awk -F "dev " '{print $2}' | cut -d " " -f1)
 LANHostGrepEx=$(ip -br addr show $LANDevice | awk '{print $3}' | awk -F "." '{printf "%s.%s.%s." , $1,$2,$3 }')
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
usage () {
cat << USAGE
 Disk free frontend - display free disk space - version $VERSION
 Usage: $(basename $0) <option>

 -h, --help      	display help
 -v, --version   	display version
 -m, --monochrome	disable color
 -s, --sumary		print column summary ( disabled )
 -l, --listconfig	show configuration
 -c, --configure 	create new configuration
 -r, --reconfigure 	reconfigure configuration
USAGE
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
configure_dialog () {

 # create config file
 ConfigParameterList=$(cat $0 | grep -A70 "configure_dialog () {" | grep "read -e -p \" Enter" | awk -F " " '{print $NF}')
 #ConfigParameterList=$(cat $0 | sed -n '/configure_dialog () /,/exit/p' | grep '\-i "\$' | awk -F " " '{print $NF}')	# TODO search sed escape for: { }
 DetectedOS=$(cat /etc/*release* | tac | grep PRETTY_NAME | head -n1 | cut -d "=" -f2 | tr -d '"')

 if [[ -n $(grep Sailfish <<< $DetectedOS) ]]; then
	# Sailfish OS mod config table. read -i parameter missing in Sailfish OS => shell config dialog disabled
	if [[ -n $(cat $ConfigFile 2> /dev/null | grep "Reconfigure=true") ]]; then
		sed -i '/Reconfigure=true/d'  $ConfigFile
		sed -i '/CreateNewConfig=true/d'  $ConfigFile
		nano $ConfigFile
	else
		# reload default configuration
		rm -f $ConfigFile
		OperatingSystem=$DetectedOS
		FSLocalSystems="/"
		FSLocalStorage="$(df -hTP| grep -w "/home$"|cut -d " " -f1) $(mount -l | grep " /run/media/nemo" | cut -d " " -f3)"
		FSRemote="ssh fuse smb"
		SortFSColumnSystem="7"
		SortFSColumnStorage="7"
		SortFSColumnRemote="7"
		FrameColor="1"
		ColumnHeaderColor="2"
		ColumnSumaryColor="3"
		GraphThresholdLow="59"
		GraphThresholdMid="89"
		GraphThresholdHigh="100"
		GraphRoundThreshold="5"
		GraphColorLow="2"
		GraphColorMid="3"
		GraphColorHigh="1"
		ColumnSumaryCalc="disabled"
	fi
 else
	# display var input prompt and default value, enter/edit value
	df -hT | grep -v tmpfs
	printf "\n"																		# varname in configfile
	read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " 		-i "${FSLocalSystems:-$(df | grep -w "/"    |cut -d " " -f1)}" 	FSLocalSystems
	read -e -p " Enter local storage filesystems (storage e.g. sda5 sdb1 /home ...): " 	-i "${FSLocalStorage:-$(df | grep -w "/home$"|cut -d " " -f1)}"	FSLocalStorage
	read -e -p " Enter remote  FSs (e.g. fuse ssh smb ...): " 				-i "${FSRemote:-ssh fuse smb}"  				FSRemote
	read -e -p " Enter sorting column number for FS => local systems: " 			-i "${SortFSColumnSystem:-7}" 					SortFSColumnSystem
	read -e -p " Enter sorting column number for FS => local storage: " 			-i "${SortFSColumnStorage:-7}"  				SortFSColumnStorage
	read -e -p " Enter sorting column number for FS => remote storage: " 			-i "${SortFSColumnRemote:-7}"  					SortFSColumnRemote
	read -e -p " Enter frame color ( default red ): " 					-i "${FrameColor:-1}" 						FrameColor
	read -e -p " Enter column header color (default green): " 				-i "${ColumnHeaderColor:-2}" 					ColumnHeaderColor
	read -e -p " Enter column summary color (default green): " 				-i "${ColumnSumaryColor:-3}" 					ColumnSumaryColor
	read -e -p " Enter graph range low % (default 0-59): 0-" 				-i "${GraphThresholdLow:-59}" 					GraphThresholdLow
	read -e -p " Enter graph range mid % (default 60-89): $(($GraphThresholdLow +1 ))-"  	-i "${GraphThresholdMid:-89}" 					GraphThresholdMid
	read -e -p " Enter graph range high % (default 90-100): $(($GraphThresholdMid +1 ))-" 	-i "${GraphThresholdHigh:-100}" 				GraphThresholdHigh
	GraphRangeLow=$(echo 0-$GraphThresholdLow)
	GraphRangeMid="$(( $GraphThresholdLow +1 ))-$GraphThresholdMid"
	GraphRangeHigh="$(( $GraphThresholdMid +1 ))-100"
	read -e -p " Enter graph round threshold $GraphRoundThreshold (default 5): " 		-i "${GraphRoundThreshold:-5}" 					GraphRoundThreshold
	read -e -p " Enter graph color low $GraphRangeLow% (default green): " 			-i "${GraphColorLow:-2}" 					GraphColorLow
	read -e -p " Enter graph color mid $GraphRangeMid% (default yellow): " 			-i "${GraphColorMid:-3}" 					GraphColorMid
	read -e -p " Enter graph color high $GraphRangeHigh% (default red): " 			-i "${GraphColorHigh:-1}" 					GraphColorHigh
	read -e -p " Enter default column sumary output (enable|disable): " 			-i "${ColumnSumaryCalc:-disabled}" 				ColumnSumaryCalc
	read -e -p " Enter operating system: " 							-i "${OperatingSystem:-$DetectedOS}"	 			OperatingSystem

	# set dummy var for empty value to avoid grep error
	if [[ -z $FSLocalStorage ]]; then
		FSLocalStorage=none
	fi

	# print new Vars
	printf "\n new configuration values: \n\n"
	for i in $ConfigParameterList; do
		echo " $i=\""$(eval echo $(echo "$"$i))\"
	done

	# check for existing config file
	if [[ -s $ConfigFile  ]]; then
		printf "\n"
		read -e -p " overwrite existing configuration (y/n) " -i "y" OverwriteConfig
		if [[ $OverwriteConfig == [yY] ]]; then
			rm $ConfigFile
		else
			sed -i '/Reconfigure=true/d'  $ConfigFile
			sed -i '/CreateNewConfig=true/d'  $ConfigFile
			printf "\n existing configuration :\n\n"
			cat $ConfigFile
			exit
		fi
	fi
 fi

 # write Vars to config file
 echo "#created $(date +%F)" > $ConfigFile
 for i in $ConfigParameterList; do
	echo "$i=\""$(eval echo $(echo "$"$i))\" >> $ConfigFile
 done

 printf "\n configuration saved in: $ConfigFile\n"

 $0
 exit
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
load_processing_vars () {
 # define colors
 FrameColor=$(tput setaf $FrameColor)
 ColumnHeaderColor=$(tput setaf $ColumnHeaderColor)
 ColumnSumaryColor=$(tput setaf $ColumnSumaryColor)
 GraphColorLow=$(tput setaf $GraphColorLow)
 GraphColorMid=$(tput setaf $GraphColorMid)
 GraphColorHigh=$(tput setaf $GraphColorHigh)
 ResetColor=$(tput sgr0)

 if [[ -n $MonochromeOutput ]]; then
	FrameColor=$(tput setaf 7)
	ColumnHeaderColor=$(tput setaf 7)
	ColumnSumaryColor=$(tput setaf 7)
	GraphColorLow=$(tput setaf 7)
	GraphColorMid=$(tput setaf 7)
	GraphColorHigh=$(tput setaf 7)
	SeperatorLine=$(echo $(tput setaf 7)"-------------------------------------------------------------------------------------------------------" $(tput sgr0))
 fi

 ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
 SeperatorLine=$(echo $FrameColor"----------------------------------------------------------------------------------------------------------$ResetColor"	)

 # define/filter df output
 FSLocalSystemList=$(df -hTP | sed '1,1d'| \
			egrep -w $(echo $FSLocalSystems| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnSystem )

 FSLocalStorageList=$(df -hTP | sed '1,1d' | grep -v localhost | \
			egrep    $(echo $FSLocalStorage| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage )

 FSRemoveableList=$(df -hTP | sed '1,1d' | grep -v tmpfs | \
			egrep -v $(echo $FSLocalSystems $FSLocalStorage $FSRemote| tr " " "|") | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage)

 FSRemoteList=$(df -hTP | sed '1,1d' | \
			egrep -w $(echo $FSRemote| tr " " "|")  | sed 's/:/ _/g' | awk -F " " '{print $1,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnRemote )

}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
check_for_LAN_host () {

 # write vars: FSRemoteListLAN / FSRemoteListLAN from FSRemoteList
 SAVEIFS=$IFS
 IFS=$(echo -en "\n\b")
 for HostLocation in $FSRemoteList ; do

	# get host IP
	HostAdress=$(echo "$HostLocation" | awk -F "@" '{printf "%s \n", $2}' | cut -d " " -f1)
	if [[ -n $(grep ^[[:digit:]] <<< $HostAdress) ]]; then
		HostIP="$HostAdress"
	elif   [[ -n $(grep ^[[:alpha:]] <<< $HostAdress) ]]; then
		HostIP=$(nslookup $HostAdress | grep "Address: " | awk '{print $2}')
	fi

	if [[ -n $( egrep "$LANHostGrepEx|127.0.0.1" <<< $HostIP)  ]]; then
		# "$HostIP is LAN"
		FSRemoteListLAN=$(echo -en "$FSRemoteListLAN""\n""$HostLocation" )
	else 
		# "$HostIP is WAN"
		FSRemoteListWAN=$(echo -en "$FSRemoteListWAN""\n""$HostLocation" )
	fi
 done
 IFS=$SAVEIFS
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------
calculate_SI_prefix () {
 CalcResult=$(	 if   [[ $(wc -m <<< $1) -gt 13 ]]; then
			printf $(bc -l <<< $1/2162516033536)P
		 elif [[ $(wc -m <<< $1) -gt 10 ]]; then
			printf $(bc -l <<< $1/1073741824)T
		 elif [[ $(wc -m <<< $1) -gt 7 ]]; then
			printf $(bc -l <<< $1/1048576)G
		 elif [[ $(wc -m <<< $1) -gt 4 ]]; then
			printf $(bc -l <<< $1/1024)M
		 elif [[ $(wc -m <<< $1) -gt 1 ]]; then
			printf "$1 K"
		 fi )

 printf $(echo $CalcResult | sed 's/^\./0./' | cut -c1-4 | sed 's/\.\$//' |sed  's/[ .]*$//' )
 # append prefix
 printf "$(echo $CalcResult | rev | cut -c1) \n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
get_filesystem_classes () {
 # get filesystemclass values
 FSLocalSystemListCalc=$(df -hTP | egrep $(echo $FSLocalSystems| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 FSLocalStorageListCalc=$(df -hTP | egrep $( echo $FSLocalStorage| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 if [[ -n $(grep Sailfish <<< $DetectedOS) ]]; then
	FSRemoteListCalc=$(df -hTP | egrep $(echo $FSRemote| tr " " "|") | grep -v alien | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')	# Sailfish mod: | grep -v alien 
 else
	FSRemoteListCalc=$(df -hTP | egrep $(echo $FSRemote| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 fi

 # check available filesystem classes and set parameter
 if [[ -n $FSLocalSystemListCalc ]]; then  	FSClassList=FSLocalSystemList				; FSClassSystem=true ;fi
 if [[ -n $FSLocalStorageListCalc ]]; then 	FSClassList=$(echo "$FSClassList" FSLocalStorageList) 	; FSClassStorage=true ;fi
 if [[ -n $FSRemoteListCalc ]]; then 		FSClassList=$(echo "$FSClassList" FSRemoteList) 	; FSClassRemote=true ;fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
calculate_summary_values () {
 # set storage class values
 for FSClass in $FSClassList ; do
	ColumnCounter=0
	# set column values
	for Column in Size Used Avail; do
		ColumnCounter=$(($ColumnCounter+1))
		# set varnames and calculate values in byte
		eval $(echo "$FSClass""$Column"Raw)=$(bc -l <<< $(eval echo '"'"$""$(eval echo "$FSClass"Calc)"'"' | awk -F " " '{printf "+" $'$ColumnCounter' }' | cut -c 2-1000)) 2>/dev/null
		# calculate SI prefix
		eval $(echo "$FSClass""$Column")=$(calculate_SI_prefix $(eval echo $(echo "$"$(echo "$FSClass""$Column"Raw))))
	done
	# caculate used percent for each filesystemclass
        eval $(echo "$FSClass"UsedPercent)=$(bc -l <<< $(eval echo '"'"$""$(eval echo "$FSClass"UsedRaw)"'"' / '"'"$""$(eval echo "$FSClass"SizeRaw)"'"' '"*"' 100) | cut -d "." -f1)%
 done

 SummaryLineLocalSystem="$FSLocalSystemListSize $FSLocalSystemListUsed $FSLocalSystemListAvail $(echo $FSLocalSystemListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSLocalSystemListUsedPercent")"
 SummaryLineLocalStorage="$FSLocalStorageListSize $FSLocalStorageListUsed $FSLocalStorageListAvail $(echo $FSLocalStorageListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSLocalStorageListUsedPercent")"
 SummaryLineRemote="$FSRemoteListSize $FSRemoteListUsed $FSRemoteListAvail $(echo $FSRemoteListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSRemoteListUsedPercent")"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser_list () {
 echo "$@" | awk -F " " '{printf " %-30s %10s %9s  %6s   %6s   %6s    %11s   %-20s \n", $1, $2, $3, $4, $5, $6, $8, $7}'
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph_star () {
 for i in `seq 10 10 $GraphValue`; do
	printf "*"
 done
 printf "\n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph () {
 printf $ResetColor
 GraphValue=$(( $(echo "$1" | tr " " "\n" | grep "%" | sed 's/[^0-9]*//g' ) + $GraphRoundThreshold ))
 if   [[ $GraphValue -le $GraphThresholdLow ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorLow'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $GraphThresholdMid ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorMid'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $(( $GraphThresholdHigh + $GraphRoundThreshold )) ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorHigh'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_output_line () {
 SAVEIFS=$IFS
 IFS=$(echo -en "\n\b")
 # proccessing each filesystem input line
 for i in $1 ; do
	print_parser_list "$i $(print_graph $i)"
 done
 IFS=$SAVEIFS
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check config   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 if   [[ -s $ConfigFile  ]] && [[ -z $(cat $ConfigFile | grep "Reconfigure=true\|CreateNewConfig=true") ]]; then
	# read config file
	source $ConfigFile

 elif [[ -s $ConfigFile  ]] && [[ -n $(cat $ConfigFile | grep "Reconfigure=true") ]]; then
	# read config and reconfigure
	source $ConfigFile
 	configure_dialog

 elif [[ ! -s $ConfigFile  ]] || [[ -n $(cat $ConfigFile | grep "CreateNewConfig=true") ]]; then
	# create new config file
	configure_dialog
 fi
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check options   ############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 load_processing_vars
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 get_filesystem_classes
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 check_for_LAN_host
#-------------------------------------------------------------------------------------------------------------------------------------------------------

 case $1 in
     	-[hv]|--help|--version)	usage
				exit;;
	-m|--monochrome)	MonochromeOutput=true
				load_processing_vars;;
#	-s|--sumary)		calculate_summary_values
#				PrintSummary=true;;
	-l|--listconfig) 	cat $ConfigFile
				exit ;;
	-c|--configure)		echo "CreateNewConfig=true" >> $ConfigFile
				$0
				exit;;
	-r|--reconfigure)	echo "Reconfigure=true" >> $ConfigFile
				$0
				exit;;
	?*)			usage
				exit;;
 esac

#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   print output   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------

 printf "$SeperatorLine \n"
 printf "$ColumnHeaderColor" && print_parser_list "$ColumnHeader"
 printf "$SeperatorLine \n"

 printf " MainSystem $FrameColor|$ColumnSumaryColor $(echo $SummaryLineLocalSystem  | awk -F " " '{printf " %32s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
 printf "$FrameColor------------+ $ResetColor\n"
 print_output_line "$FSLocalSystemList"
 printf "$SeperatorLine \n"

 if [[ -n $FSClassStorage ]]; then
  printf " Storage FileSystems $FrameColor|$ColumnSumaryColor $(echo $SummaryLineLocalStorage  | awk -F " " '{printf " %23s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor---------------------+$ResetColor\n"
  print_output_line "$FSLocalStorageList"
  printf "$SeperatorLine \n"
 fi

 if [[ -n $FSRemoveableList ]]; then
  printf " Removeable Drives $FrameColor|$ColumnSumaryColor $(echo $SummaryLineRemote  | awk -F " " '{printf " %8s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor-------------------+$ResetColor\n"
  print_output_line "$FSRemoveableList"
  printf "$SeperatorLine \n"
 fi

 if [[ -n $FSRemoteListLAN ]]; then
  printf " Network shares (LAN) $FrameColor|$ColumnSumaryColor $(echo $SummaryLineRemote  | awk -F " " '{printf " %8s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor----------------------+$ResetColor\n"
  print_output_line "$FSRemoteListLAN"
  printf "$SeperatorLine \n"
 fi

 if [[ -n $FSRemoteListWAN ]]; then
  printf " Network shares (WAN) $FrameColor|$ColumnSumaryColor $(echo $SummaryLineRemote  | awk -F " " '{printf " %8s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor----------------------+$ResetColor\n"
  print_output_line "$FSRemoteListWAN"
  printf "$SeperatorLine \n"
 fi

#-------------------------------------------------------------------------------------------------------------------------------------------------------

exit 0

#-------------------------------------------------------------------------------------------------------------------------------------------------------
# changelog
#
# 2.1.9 separate Network shares LAN/WAN
