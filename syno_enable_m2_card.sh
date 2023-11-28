#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Enable M.2 PCIe cards in Synology NAS that don't officially support them.
#
# Allows using your E10M20-T1, M2D20, M2D18, M2D17 or FX2422N cards
# in Synology NAS models that aren't on their supported model list.
#
# Github: https://github.com/007revad/Synology_enable_M2_card
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -i /volume1/scripts/syno_enable_m2_card.sh
#-----------------------------------------------------------------------------------

scriptver="v2.0.7"
script=Synology_enable_M2_card
repo="007revad/Synology_enable_M2_card"

# Check BASH variable is bash
if [ ! "$(basename "$BASH")" = bash ]; then
    echo "This is a bash script. Do not run it with $(basename "$BASH")"
    printf \\a
    exit 1
fi

#echo -e "bash version: $(bash --version | head -1 | cut -d' ' -f4)\n"  # debug

# Shell Colors
#Black='\e[0;30m'    # ${Black}
#Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'    # ${Green}
Yellow='\e[0;33m'   # ${Yellow}
#Blue='\e[0;34m'     # ${Blue}
#Purple='\e[0;35m'   # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'    # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){ 
    printf \\a
}

usage(){ 
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -c, --check      Check M.2 card status
  -r, --restore    Restore backup to undo changes
  -h, --help       Show this help message
  -v, --version    Show the script version

EOF
    exit 0
}


scriptversion(){ 
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
    exit 0
}


# Save options used
args=("$@")


# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -a \
    -l check,restore,help,version,log,debug -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -h|--help)          # Show usage options
                usage
                ;;
            -v|--version)       # Show script version
                scriptversion
                ;;
            -l|--log)           # Log
                #log=yes
                ;;
            -d|--debug)         # Show and log debug info
                debug=yes
                ;;
            -c|--check)         # Check current settings
                check=yes
                break
                ;;
            -r|--restore)       # Restore original settings
                restore=yes
                break
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo -e "Invalid option '$1'\n"
                usage "$1"
                ;;
        esac
        shift
    done
else
    echo
    usage
fi


if [[ $debug == "yes" ]]; then
    # set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`:.$LINENO:'
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM major and minor versions
#dsm=$(get_key_value /etc.defaults/VERSION majorversion)
#dsminor=$(get_key_value /etc.defaults/VERSION minorversion)
#if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "1" ]]; then
#    dsm72="yes"
#fi
#if [[ $dsm -gt "6" ]] && [[ $dsminor -gt "0" ]]; then
#    dsm71="yes"
#fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
modelname="$model"

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=$(get_key_value /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n"

# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo "Using options: ${args[*]}"
fi


#------------------------------------------------------------------------------
# Check latest release with GitHub API

get_latest_release(){ 
    # Curl timeout options:
    # https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
    curl --silent -m 10 --connect-timeout 5 \
        "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |          # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # Pluck JSON value
}

tag=$(get_latest_release "$repo")
shorttag="${tag:1}"
#scriptpath=$(dirname -- "$0")

# Get script location
# https://stackoverflow.com/questions/59895/
source=${BASH_SOURCE[0]}
while [ -L "$source" ]; do # Resolve $source until the file is no longer a symlink
    scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    # If $source was a relative symlink, we need to resolve it 
    # relative to the path where the symlink file was located
    [[ $source != /* ]] && source=$scriptpath/$source
done
scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
#echo "Script location: $scriptpath"  # debug


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort &> /dev/null ; then
    echo -e "${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    if [[ -f $scriptpath/$script-$shorttag.tar.gz ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    elif [[ -d $scriptpath/$script-$shorttag ]]; then
        # They have the latest version extracted but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    else
        echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
        read -r -t 30 reply
        if [[ ${reply,,} == "y" ]]; then
            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -LJO -m 30 --connect-timeout 5 "$url";
                then
                    echo -e "${Error}ERROR ${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR ${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            # Copy new script sh files to script location
                            if ! cp -p "/tmp/$script-$shorttag/"*.sh "$scriptpath"; then
                                copyerr=1
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag .sh file(s) to:\n $scriptpath"
                            else                   
                                # Set permsissions on CHANGES.txt
                                if ! chmod 744 "$scriptpath/"*.sh ; then
                                    permerr=1
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath *.sh file(s)"
                                fi
                            fi

                            # Copy new CHANGES.txt file to script location
                            if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt" "$scriptpath"; then
                                copyerr=1
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                            else                   
                                # Set permsissions on CHANGES.txt
                                if ! chmod 744 "$scriptpath/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi
                            fi

                            # Delete downloaded .tar.gz file
                            if ! rm "/tmp/$script-$shorttag.tar.gz"; then
                                #delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag.tar.gz!"
                            fi

                            # Delete extracted tmp files
                            if ! rm -r "/tmp/$script-$shorttag"; then
                                #delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag!"
                            fi

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag and changes.txt downloaded to:"\
                                    "$scriptpath"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "$0" "${args[@]}"
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR ${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                    fi
                fi
            else
                echo -e "${Error}ERROR ${Off} Failed to cd to /tmp!"
            fi
        fi
    fi
fi


#------------------------------------------------------------------------------
# Set file variables

if [[ -f /etc.defaults/model.dtb ]]; then  # Is device tree model
    # Get syn_hw_revision, r1 or r2 etc (or just a linefeed if not a revision)
    hwrevision=$(cat /proc/sys/kernel/syno_hw_revision)

    # If syno_hw_revision is r1 or r2 it's a real Synology,
    # and I need to edit model_rN.dtb instead of model.dtb
    if [[ $hwrevision =~ r[0-9] ]]; then
        #echo "hwrevision: $hwrevision"  # debug
        hwrev="_$hwrevision"
    fi

    dtb_file="/etc.defaults/model${hwrev}.dtb"
    dtb2_file="/etc/model${hwrev}.dtb"
    #dts_file="/etc.defaults/model${hwrev}.dts"
    dts_file="/tmp/model${hwrev}.dts"
fi

#synoinfo="/etc.defaults/synoinfo.conf"
m2cardconf="/usr/syno/etc.defaults/adapter_cards.conf"
m2cardconf2="/usr/syno/etc/adapter_cards.conf"


#------------------------------------------------------------------------------
# Restore changes from backups

if [[ $restore == "yes" ]]; then
    echo

    if [[ -f ${dtb_file}.bak ]] || [[ -f ${m2cardconf}.bak ]] ; then

        # Restore adapter_cards.conf from backup
        # /usr/syno/etc.defaults/adapter_cards.conf
        if [[ -f ${m2cardconf}.bak ]]; then
            if cp -p "${m2cardconf}.bak" "${m2cardconf}"; then
                echo -e "Restored $(basename -- "$m2cardconf")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${m2cardconf}!\n"
            fi
        fi
        # /usr/syno/etc/adapter_cards.conf
        if [[ -f ${m2cardconf2}.bak ]]; then
            if cp -p "${m2cardconf2}.bak" "${m2cardconf2}"; then
                echo -e "Restored $(basename -- "$m2cardconf2")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${m2cardconf2}!\n"
            fi
        fi

        # Restore model.dtb from backup
        if [[ -f ${dtb_file}.bak ]]; then
            # /etc.default/model.dtb
            if cp -p "${dtb_file}.bak" "${dtb_file}"; then
                echo -e "Restored $(basename -- "$dtb_file")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${dtb_file}!\n"
            fi
            # Restore /etc/model.dtb from /etc.default/model.dtb
            if cp -p "${dtb_file}.bak" "${dtb2_file}"; then
                echo -e "Restored $(basename -- "$dtb2_file")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${dtb2_file}!\n"
            fi
        fi

        if [[ -z $restoreerr ]]; then
            echo -e "Restore successful."
        fi
    else
        echo -e "Nothing to restore."
    fi
    exit
fi


#----------------------------------------------------------
# Check currently enabled M2 cards

check_key_value(){ 
    # $1 is path/file
    # $2 is key
    setting="$(get_key_value "$1" "$2")"
    if [[ -f $1 ]]; then
        if [[ -n $2 ]]; then
            echo -e "${Yellow}$2${Off} = $setting" >&2
        else
            echo -e "Key name not specified!" >&2
        fi
    else
        echo -e "File not found: $1" >&2
    fi
}

check_section_key_value(){ 
    # $1 is path/file
    # $2 is section
    # $3 is key
    # $4 is description
    setting="$(get_section_key_value "$1" "$2" "$3")"
    if [[ -f $1 ]]; then
        if [[ -n $2 ]]; then
            if [[ -n $3 ]]; then
                if [[ $setting == "yes" ]]; then
                    echo -e "${Yellow}$4${Off} is enabled for ${Cyan}$3${Off}" >&2
                else
                    echo -e "$4 is ${Cyan}not{Off} enabled for $3" >&2
                fi
            else
                echo -e "Key name not specified!" >&2
            fi
        else
            echo -e "Section name not specified!" >&2
        fi
    else
        echo -e "File not found: $1" >&2
    fi
}

check_modeldtb(){ 
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f "${dtb_file}" ]]; then
        if grep --text "$1" "${dtb_file}" >/dev/null; then
            echo -e "${Yellow}$1${Off} is enabled in ${dtb_file}" >& 2
        else
            echo -e "$1 is ${Cyan}not${Off} enabled in ${dtb_file}" >& 2
        fi
    #else
    #    echo -e "No ${dtb2_file}" >& 2
    fi
    if [[ -f "${dtb2_file}" ]]; then
        if grep --text "$1" "${dtb2_file}" >/dev/null; then
            echo -e "${Yellow}$1${Off} is enabled in ${dtb2_file}" >& 2
        else
            echo -e "$1 is ${Cyan}not${Off} enabled in ${dtb2_file}" >& 2
        fi
    #else
    #    echo -e "No ${dtb2_file}" >& 2
    fi
}


if [[ $check == "yes" ]]; then
    # Only check /usr/syno/etc.defaults/adapter_cards.conf

    echo ""
    check_section_key_value "$m2cardconf" E10M20-T1_sup_nic "${modelname}" "E10M20-T1 NIC"
    check_section_key_value "$m2cardconf" E10M20-T1_sup_nvme "${modelname}" "E10M20-T1 NVMe"
    #check_section_key_value "$m2cardconf" E10M20-T1_sup_sata "${modelname}" "E10M20-T1 SATA"
    check_modeldtb "E10M20-T1"

    echo ""
    check_section_key_value "$m2cardconf" M2D20_sup_nvme "${modelname}" "M2D20 NVMe"
    check_modeldtb "M2D20"

    echo ""
    check_section_key_value "$m2cardconf" M2D18_sup_nvme "${modelname}" "M2D18 NVMe"
    check_section_key_value "$m2cardconf" M2D18_sup_sata "${modelname}" "M2D18 SATA"
    check_modeldtb "M2D18"

    echo ""
    check_section_key_value "$m2cardconf" M2D17_sup_sata "${modelname}" "M2D17 SATA"
    check_modeldtb "M2D17"

    #echo ""
    #check_section_key_value "$m2cardconf" FX2422N_sup_nvme "${modelname}" "FX2422N NVMe"
    ##check_modeldtb "FX2422N"

    echo ""
    exit
fi


#------------------------------------------------------------------------------
# Enable unsupported Synology M2 PCIe cards

# In DSM 7.2 every NAS model has the same /usr/syno/etc.defaults/adapter_cards.conf

# DS1821+ and DS1621+ also need edited device tree blob file /etc.defaults/model.dtb
# To support M2D18:
#   DS1823xs+, DS2422+, RS2423+, RS2421+, RS2421RP+ and RS2821RP+ need edited model.dtb
#   RS822+, RS822RP+, RS1221+ and RS1221RP+ with DSM older than 7.2 need model.dtb from DSM 7.2

backupdb(){ 
    # Backup file if needed
    if [[ ! -f "$1.bak" ]]; then
        if [[ $(basename "$1") == "synoinfo.conf" ]]; then
            echo "" >&2  # Formatting for stdout
        fi
        if cp -p "$1" "$1.bak"; then
            echo -e "Backed up $1" >&2
        else
            echo -e "${Error}ERROR 5${Off} Failed to backup $1!" >&2
            return 1
        fi
    fi
    # Fix permissions if needed
    octal=$(stat -c "%a %n" "$1" | cut -d" " -f1)
    if [[ ! $octal -eq 644 ]]; then
        chmod 644 "$1"
    fi
    return 0
}

enable_card(){ 
    # $1 is the file
    # $2 is the section
    # $3 is the card model and mode
    if [[ -f $1 ]] && [[ -n $2 ]] && [[ -n $3 ]]; then
        backupdb "$m2cardconf"
        backupdb "$m2cardconf2"

        # Check if section exists
        if ! grep '^\['"$2"'\]$' "$1" >/dev/null; then
            echo -e "Section [$2] not found in $(basename -- "$1")!" >&2
            return
        fi
        # Check if already enabled
        #
        # No idea if "cat /proc/sys/kernel/syno_hw_version" returns upper or lower case RP
        # "/usr/syno/etc.defaults/adapter_cards.conf" uses lower case rp but upper case RS
        # So we'll convert RP to rp when needed.
        #
        modelrplowercase=${modelname//RP/rp}
        val=$(get_section_key_value "$1" "$2" "$modelrplowercase")
        if [[ $val != "yes" ]]; then
            # /usr/syno/etc.defaults/adapter_cards.conf
            if set_section_key_value "$1" "$2" "$modelrplowercase" yes; then
                # /usr/syno/etc/adapter_cards.conf
                set_section_key_value "$m2cardconf2" "$2" "$modelrplowercase" yes
                echo -e "Enabled ${Yellow}$3${Off} for ${Cyan}$modelname${Off}" >&2
                reboot=yes
            else
                echo -e "${Error}ERROR 9${Off} Failed to enable $3 for ${modelname}!" >&2
            fi
        else
            echo -e "${Yellow}$3${Off} already enabled for ${Cyan}$modelname${Off}" >&2
        fi
    fi
}

dts_m2_card(){ 
# $1 is the card model
# $2 is the dts file

# Remove last }; so we can append to dts file
sed -i '/^};/d' "$2"

# Append PCIe M.2 card node to dts file
if [[ $1 == E10M20-T1 ]] || [[ $1 == M2D20 ]]; then
    cat >> "$2" <<EOM2D

	$1 {
		compatible = "Synology";
		model = "synology_${1,,}";
		power_limit = "14.85,14.85";

		m2_card@1 {

			nvme {
				pcie_postfix = "00.0,08.0,00.0";
				port_type = "ssdcache";
			};
		};

		m2_card@2 {

			nvme {
				pcie_postfix = "00.0,04.0,00.0";
				port_type = "ssdcache";
			};
		};
	};
};
EOM2D

elif [[ $1 == M2D18 ]]; then
    cat >> "$2" <<EOM2D18

	M2D18 {
		compatible = "Synology";
		model = "synology_m2d18";
		power_limit = "9.9,9.9";

		m2_card@1 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x00>;
			};

			nvme {
				pcie_postfix = "00.0,04.0,00.0";
				port_type = "ssdcache";
			};
		};

		m2_card@2 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x01>;
			};

			nvme {
				pcie_postfix = "00.0,05.0,00.0";
				port_type = "ssdcache";
			};
		};
	};
};
EOM2D18

elif [[ $1 == M2D17 ]]; then
    cat >> "$2" <<EOM2D17

	M2D17 {
		compatible = "Synology";
		model = "synology_m2d17";
		power_limit = "9.9,9.9";

		m2_card@1 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x00>;
			};
		};

		m2_card@2 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x01>;
			};
		};
	};
};
EOM2D17

fi
}

install_binfile(){ 
    # install_binfile <file> <file-url> <destination> <chmod> <bundled-path> <hash>
    # example:
    #  file_url="https://raw.githubusercontent.com/${repo}/main/bin/dtc"
    #  install_binfile dtc "$file_url" /usr/bin/bc a+x bin/dtc

    if [[ -f "${scriptpath}/$5" ]]; then
        binfile="${scriptpath}/$5"
        echo -e "\nInstalling ${1}"
    elif [[ -f "${scriptpath}/$(basename -- "$5")" ]]; then
        binfile="${scriptpath}/$(basename -- "$5")"
        echo -e "\nInstalling ${1}"
    else
        # Download binfile
        if [[ $autoupdate == "yes" ]]; then
            reply=y
        else
            echo -e "\nNeed to download ${1}"
            echo -e "${Cyan}Do you want to download ${1}?${Off} [y/n]"
            read -r -t 30 reply
        fi
        if [[ ${reply,,} == "y" ]]; then
            echo -e "\nDownloading ${1}"
            if ! curl -kL -m 30 --connect-timeout 5 "$2" -o "/tmp/$1"; then
                echo -e "${Error}ERROR${Off} Failed to download ${1}!"
                return
            fi
            binfile="/tmp/${1}"

            printf "Downloaded md5: "
            md5sum -b "$binfile" | awk '{print $1}'

            md5=$(md5sum -b "$binfile" | awk '{print $1}')
            if [[ $md5 != "$6" ]]; then
                echo "Expected md5:   $6"
                echo -e "${Error}ERROR${Off} Downloaded $1 md5 hash does not match!"
                exit 1
            fi
        else
            echo -e "${Error}ERROR${Off} Cannot add M2 PCIe card without ${1}!"
            exit 1
        fi
    fi

    # Set binfile executable
    chmod "$4" "$binfile"

    # Copy binfile to destination
    cp -p "$binfile" "$3"
}

edit_dts(){ 
    # $1 is M.2 card model
    # Edit model.dts if needed
    if ! grep "$1" "$dtb_file" >/dev/null; then
        dts_m2_card "$1" "$dts_file"
        echo -e "Added ${Yellow}$1${Off} to ${Cyan}model${hwrev}.dtb${Off}" >&2
#    else
#        echo -e "${Yellow}$1${Off} already exists in ${Cyan}model${hwrev}.dtb${Off}" >&2
    fi
}

edit_modeldtb(){ 
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f /etc.defaults/model.dtb ]]; then  # Is device tree model
        # Check if dtc exists and is executable
        if [[ ! -x $(which dtc) ]]; then
            md5hash="01381dabbe86e13a2f4a8017b5552918"
            branch="main"
            file_url="https://raw.githubusercontent.com/${repo}/${branch}/bin/dtc"
            # install_binfile <file> <file-url> <destination> <chmod> <bundled-path> <hash>
            install_binfile dtc "$file_url" /usr/sbin/dtc "a+x" bin/dtc "$md5hash"
        fi

        # Check again if dtc exists and is executable
        if [[ -x /usr/sbin/dtc ]]; then

            # Backup model.dtb
            if ! backupdb "$dtb_file"; then
                echo -e "${Error}ERROR${Off} Failed to backup ${dtb_file}!" >&2
            fi

            # Output model.dtb to model.dts
            dtc -q -I dtb -O dts -o "$dts_file" "$dtb_file"  # -q Suppress warnings
            chmod 644 "$dts_file"

            # Edit model.dts
            for c in "${cards[@]}"; do
                # Edit model.dts if needed
                if ! grep "$c" "$dtb_file" >/dev/null; then
                    dts_m2_card "$c" "$dts_file"
                    echo -e "Added ${Yellow}$c${Off} to ${Cyan}model${hwrev}.dtb${Off}" >&2
                else
                    echo -e "${Yellow}$c${Off} already exists in ${Cyan}model${hwrev}.dtb${Off}" >&2
                fi
            done

            # Compile model.dts to model.dtb
            dtc -q -I dts -O dtb -o "$dtb_file" "$dts_file"  # -q Suppress warnings

            # Set owner and permissions for model.dtb
            chmod a+r "$dtb_file"
            chown root:root "$dtb_file"
            cp -pu "$dtb_file" "$dtb2_file"  # Copy dtb file to /etc
        else
            echo -e "${Error}ERROR${Off} Missing /usr/sbin/dtc or not executable!" >&2
        fi
    fi
}


#------------------------------------------------------------------------------
# Select M2 card model to enable

PS3="Select your M.2 Card: "
options=("E10M20-T1" "M2D20" "M2D18" "M2D17" "ALL" "Quit")
select choice in "${options[@]}"; do
    case "$choice" in
        E10M20-T1)
            echo ""
            enable_card "$m2cardconf" E10M20-T1_sup_nic "E10M20-T1 NIC"
            enable_card "$m2cardconf" E10M20-T1_sup_nvme "E10M20-T1 NVMe"
            #enable_card "$m2cardconf" E10M20-T1_sup_sata "E10M20-T1 SATA"
            cards=(E10M20-T1) && edit_modeldtb
            break
        ;;
        M2D20)
            echo ""
            enable_card "$m2cardconf" M2D20_sup_nvme "M2D20 NVMe"
            cards=(M2D20) && edit_modeldtb
            break
        ;;
        M2D18)
            echo ""
            enable_card "$m2cardconf" M2D18_sup_nvme "M2D18 NVMe"
            enable_card "$m2cardconf" M2D18_sup_sata "M2D18 SATA"
            cards=(M2D18) && edit_modeldtb
            break
        ;;
        M2D17)
            echo ""
            enable_card "$m2cardconf" M2D17_sup_sata "M2D17 SATA"
            cards=(M2D17) && edit_modeldtb
            break
        ;;
        FX2422N)
            echo ""
            enable_card "$m2cardconf" FX2422N_sup_nvme "FX2422N"
            #cards=(FX2422N) && edit_modeldtb
            break
        ;;
        ALL)
            echo ""
            enable_card "$m2cardconf" E10M20-T1_sup_nic "E10M20-T1 NIC"
            enable_card "$m2cardconf" E10M20-T1_sup_nvme "E10M20-T1 NVMe"
            #enable_card "$m2cardconf" E10M20-T1_sup_sata "E10M20-T1 SATA"
            enable_card "$m2cardconf" M2D20_sup_nvme "M2D20 NVMe"
            enable_card "$m2cardconf" M2D18_sup_nvme "M2D18 NVMe"
            enable_card "$m2cardconf" M2D18_sup_sata "M2D18 SATA"
            enable_card "$m2cardconf" M2D17_sup_sata "M2D17 SATA"
            #enable_card "$m2cardconf" FX2422N_sup_nvme "FX2422N"

            cards=("E10M20-T1" "M2D20" "M2D18" "M2D17") && edit_modeldtb
            break
        ;;
        Quit)
            exit
        ;;
        *)
            echo -e "Unknown M2 card type: $choice"
        ;;
    esac
done


#------------------------------------------------------------------------------
# Finished

if [[ $reboot == "yes" ]]; then
    # Reboot prompt
    echo -e "\n${Cyan}The Synology needs to restart.${Off}"
    echo -e "Type ${Cyan}yes${Off} to reboot now."
    echo -e "Type anything else to quit (if you will restart it yourself)."
    read -r -t 10 answer
    if [[ ${answer,,} != "yes" ]]; then exit; fi

#    # Reboot in the background so user can see DSM's "going down" message
#    reboot &
    if [[ -x /usr/syno/sbin/synopoweroff ]]; then
        /usr/syno/sbin/synopoweroff -r || reboot
    else
        reboot
    fi
else
    echo -e "\nFinished"
fi

