#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Enable M.2 PCIe cards in Synology NAS that don't officially support them
#
# Allows using your E10M20-T1, M2D20, M2D18 or M2D17 cards in Synology NAS models 
# that aren't on their supported model list.
#
# Github: https://github.com/007revad/Synology_enable_M2_card
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -i /volume1/scripts/syno_enable_m2_card.sh
#-----------------------------------------------------------------------------------

scriptver="v1.0.6"
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

get_latest_release() {
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
        sort --check --version-sort &> /dev/null ; then
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
# Restore changes from backups

#synoinfo="/etc.defaults/synoinfo.conf"
m2cardconf="/usr/syno/etc.defaults/adapter_cards.conf"
modeldtb="/etc.defaults/model.dtb"

if [[ $restore == "yes" ]]; then
    echo

    if [[ -f ${modeldtb}.bak ]] || [[ -f ${m2cardconf}.bak ]] ; then

        # Restore adapter_cards.conf from backup
        if [[ -f ${m2cardconf}.bak ]]; then
            if cp -p "${m2cardconf}.bak" "${m2cardconf}"; then
                echo -e "Restored $(basename -- "$m2cardconf")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore m2cardconf.conf!\n"
            fi
        fi

        # Restore modeldtb from backup
        if [[ -f ${modeldtb}.bak ]]; then
            if cp -p "${modeldtb}.bak" "${modeldtb}"; then
                echo -e "Restored $(basename -- "$modeldtb")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore model.dtb!\n"
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
                echo -e "${Yellow}$4${Off} = $setting" >&2
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
    if [[ -f /etc.defaults/model.dtb ]]; then
        if grep --text "$1" /etc.defaults/model.dtb >/dev/null; then
            echo -e "${Yellow}$1${Off} enabled in /etc.defaults/model.dtb" >& 2
        else
            echo -e "$1 ${Cyan}not${Off} enabled in /etc.defaults/model.dtb" >& 2
        fi
    #else
    #    echo -e "No model.dtb file." >& 2
    fi
}


if [[ $check == "yes" ]]; then
    echo ""
    check_section_key_value "$m2cardconf" E10M20-T1_sup_nic "${modelname}" "E10M20-T1 NIC"
    check_section_key_value "$m2cardconf" E10M20-T1_sup_nvme "${modelname}" "E10M20-T1 NVMe"
    check_section_key_value "$m2cardconf" E10M20-T1_sup_sata "${modelname}" "E10M20-T1 SATA"
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
    # Backup database file if needed
    if [[ ! -f "$1.bak" ]]; then
        if [[ $(basename "$1") == "synoinfo.conf" ]]; then
            echo "" >&2  # Formatting for stdout
        fi
        if cp -p "$1" "$1.bak"; then
            echo -e "Backed up $(basename -- "${1}")" >&2
        else
            echo -e "${Error}ERROR 5${Off} Failed to backup $(basename -- "${1}")!" >&2
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
            if set_section_key_value "$1" "$2" "$modelrplowercase" yes; then
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

edit_modeldtb(){
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f /etc.defaults/model.dtb ]]; then
        if ! grep --text "$1" /etc.defaults/model.dtb >/dev/null; then

            # Check if the dtb file exists on github
            urldtb=https://api.github.com/repos/007revad/Synology_enable_M2_card/contents/dtb
            if curl "$urldtb" | grep dtb/"${modelname,,}"_model.dtb;
            then
                echo "" >&2
                if [[ -f ./dtb/${modelname,,}_model.dtb ]]; then
                    # Edited device tree blob exists in dtb folder with script
                    newdtb="./dtb/${modelname,,}_model.dtb"
                elif [[ -f ./${modelname,,}_model.dtb ]]; then
                    # Edited device tree blob exists with script
                    newdtb="./${modelname,,}_model.dtb"
                else
                    # Download edited device tree blob model.dtb from github
                    if cd /var/services/tmp; then
                        echo -e "Downloading ${modelname,,}_model.dtb" >&2
                        repo=https://github.com/007revad/Synology_enable_M2_card
                        url=${repo}/raw/main/dtb/${modelname,,}_model.dtb
                        curl -LJO -m 30 --connect-timeout 5 "$url"
                        echo "" >&2
                        cd "$scriptpath" || echo -e "${Error}ERROR${Off} Failed to cd to script location!"
                    else
                        echo -e "${Error}ERROR${Off} /var/services/tmp does not exist!" >&2
                    fi

                    # Check we actually downloaded the file
                    if [[ -f /var/services/tmp/${modelname,,}_model.dtb ]]; then
                        newdtb="/var/services/tmp/${modelname,,}_model.dtb"
                    else
                        echo -e "${Error}ERROR${Off} Failed to download ${modelname,,}_model.dtb!" >&2
                    fi
                fi
                if [[ -f $newdtb ]]; then
                    # Backup model.dtb
                    backupdb "$modeldtb"
                    if ! backupdb "/etc.defaults/model.dtb"; then
                        echo -e "${Error}ERROR${Off} Failed to backup /etc.defaults/model.dtb!" >&2
                    else                
                        # Move and rename downloaded model.dtb
                        if mv "$newdtb" "/etc.defaults/model.dtb"; then
                            echo -e "Enabled ${Yellow}$1${Off} in ${Cyan}model.dtb${Off}" >&2
                            reboot=yes
                        else
                            echo -e "${Error}ERROR${Off} Failed to add support for ${1}" >&2
                        fi

                        # Fix permissions if needed
                        octal=$(stat -c "%a %n" "/etc.defaults/model.dtb" | cut -d" " -f1)
                        if [[ ! $octal -eq 644 ]]; then
                            chmod 644 "/etc.defaults/model.dtb"
                        fi
                    fi
                else
                    #echo -e "${Error}ERROR${Off} Missing file ${modelname}_model.dtb" >&2
                    echo -e "${Error}ERROR${Off} Missing file $newdtb" >&2
                fi
            else
                echo -e "\n${Cyan}Contact 007revad to get an edited model.dtb file for your model.${Off}" >&2
            fi
        else
            echo -e "${Yellow}$1${Off} already enabled in ${Cyan}model.dtb${Off}" >&2
        fi
    fi
}

e10m20_t1(){
    backupdb "$m2cardconf"
    echo ""
    enable_card "$m2cardconf" E10M20-T1_sup_nic "E10M20-T1 NIC"
    enable_card "$m2cardconf" E10M20-T1_sup_nvme "E10M20-T1 NVMe"
    enable_card "$m2cardconf" E10M20-T1_sup_sata "E10M20-T1 SATA"
    edit_modeldtb "E10M20-T1"
}

m2d20(){
    backupdb "$m2cardconf"
    echo ""
    enable_card "$m2cardconf" M2D20_sup_nvme "M2D20 NVMe"
    edit_modeldtb "M2D20"
}

m2d18(){
    backupdb "$m2cardconf"
    echo ""
    enable_card "$m2cardconf" M2D18_sup_nvme "M2D18 NVMe"
    enable_card "$m2cardconf" M2D18_sup_sata "M2D18 SATA"
    edit_modeldtb "M2D18"
}

m2d17(){
    backupdb "$m2cardconf"
    echo ""
    enable_card "$m2cardconf" M2D17_sup_sata "M2D17 SATA"
}


#------------------------------------------------------------------------------
# Select M2 card model0 to enable

#echo 
PS3="Select your M.2 Card: "
options=("E10M20-T1" "M2D20" "M2D18" "M2D17" "ALL" "Quit")
#options=("E10M20-T1" "M2D20" "M2D18" "M2D17" "Quit")
select choice in "${options[@]}"; do
    case "$choice" in
        E10M20-T1)
            e10m20_t1
            break
        ;;
        M2D20)
            m2d20
            break
        ;;
        M2D18)
            m2d18
            break
        ;;
        M2D17)
            m2d17
            break
        ;;
        ALL)
            e10m20_t1
            m2d20
            m2d18
            m2d17
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

    # Reboot in the background so user can see DSM's "going down" message
    reboot &
else
    echo -e "\nFinished"
fi

