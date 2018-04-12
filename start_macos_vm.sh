#!/bin/bash

# Shamelessly stolen from https://github.com/kholia/OSX-KVM/blob/master/boot-macOS-HS.sh
#
# Create drive image:   qemu-img create -f qcow2 mac_hdd.qcow 128G
# Compact inside guest: diskutil secureErase freespace 0 /Volumes/MacOS
# Compact on host:      qemu-img convert -O qcow2 -c uncompacted.qcow compacted.qcow

SCRIPT_HOME=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")



# =====================
# Default Configuration
# =====================

MEMORY=UNSET
SCREEN_RESOLUTION=UNSET
VNC_PORT=:0
INSTALLER_IMAGE=UNSET
CREATE_NEW_DRIVE_SIZE=UNSET
VM_DIRECTORY=
SETTINGS_FILE=

# Qemu won't start otherwise
export QEMU_AUDIO_DRV=alsa

ALLOWED_RESOLUTIONS=( 640x480 800x480 800x600 832x624 960x640 1024x600 1024x768 1152x864 1152x870 1280x720 1280x768 1280x800 1280x960 1280x1024 1360x768 1366x768 1400x1050 1400x900 1600x900 1600x1200 1680x1050 1920x1080 1920x1200 1920x1440 2000x2000 2048x1536 2048x2048 2560x1440 2560x1600 )



# =========
# Functions
# =========

error() {
    set +eu
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    if [[ -n "$message" ]] ; then
        echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
    else
        echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
    fi
    exit "${code}"
}
trap 'error ${LINENO}' ERR

function list_resolutions {
    echo "Allowed resolutions:"
    echo ${ALLOWED_RESOLUTIONS[*]}
}

function is_valid_resolution {
    resolution=$1
    for i in "${ALLOWED_RESOLUTIONS[@]}"; do
        if [ "$i" == "$resolution" ]; then
            echo "true"
            return 0
        fi
    done

    echo "false"
}

function validate_parameters {
    if [ "$MEMORY" == "UNSET" ]; then
        echo "No memory size specified. Use -m to set it for the first time."
        exit 1
    fi
    if [ "$SCREEN_RESOLUTION" == "UNSET" ]; then
        echo "No screen resolution specified. Use -r to set it for the first time."
        echo "When installing the OS, it's easiest to set resolution to 1024x768."
        exit 1
    fi

    if [ $(is_valid_resolution "$SCREEN_RESOLUTION") != "true" ]; then
        echo "$SCREEN_RESOLUTION is not a valid resolution."
        list_resolutions
        exit 1
    fi

    if [ ! "$INSTALLER_IMAGE" == "UNSET" ]; then
        if [ ! -f "$INSTALLER_IMAGE" ]; then
            echo "Installer image not found: $INSTALLER_IMAGE"
            exit 1
        fi
    fi
}

function create_from_template {
    template_file=$1
    destination_file=$2

    if [ ! -f "$destination_file" ]; then
        cp "$template_file" "$destination_file"
    fi
}

function load_settings {
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
        if [ "$MEMORY" == "UNSET" ]; then
            MEMORY=$CONFIG_MEMORY_MB
        fi
        if [ "$SCREEN_RESOLUTION" == "UNSET" ]; then
            SCREEN_RESOLUTION=$CONFIG_SCREEN_RESOLUTION
        fi
    fi
}

function save_settings {
    echo "" > "$SETTINGS_FILE"
    echo "export CONFIG_MEMORY_MB=$MEMORY" >> "$SETTINGS_FILE"
    echo "export CONFIG_SCREEN_RESOLUTION=$SCREEN_RESOLUTION" >> "$SETTINGS_FILE"
}

function setup_vm {
    src_dir="$SCRIPT_HOME"
    vm_dir="$VM_DIRECTORY"
    new_drive_size="$CREATE_NEW_DRIVE_SIZE"
    mac_hdd_image="${vm_dir}/mac_hdd.qcow"

    if [ ! "$new_drive_size" == "UNSET" ]; then
        echo "Creating new $new_drive_size hdd image at $mac_hdd_image"
        if [ ! -f "$mac_hdd_image" ]; then
            mkdir -p "$vm_dir"
            qemu-img create -f qcow2 "$mac_hdd_image" $new_drive_size
        else
            echo "Error: image already exists at $mac_hdd_image"
            echo "Don't use the -c option for existing virtual machines."
            exit 1
        fi
    fi

    if [ ! -d "$vm_dir" ]; then
        echo "No such directory: $vm_dir"
        echo "If you want to create a new vm, use the -c option."
        exit 1
    fi

    if [ ! -f "$mac_hdd_image" ]; then
        echo "HDD image not found: $mac_hdd_image"
        echo "Are you sure $(dirname $mac_hdd_image) is a vm directory?"
        echo "To create a new vm, use the -c option."
        exit 1
    fi

    create_from_template "${src_dir}/Clover-1024x768.qcow2.template" "${vm_dir}/Clover.qcow2"
    create_from_template "${src_dir}/OVMF_VARS-pure-efi-1024x768.fd.template" "${vm_dir}/OVMF_VARS-pure-efi.fd"
}

function show_help {
    echo "Run High Sierra in qemu"
    echo
    echo "Usage: $0 [options] <vm directory>"
    echo
    echo "Where <vm directory> is a directory to contain the vm files"
    echo
    echo "Options:"
    echo "    -?:            Show this help screen."
    echo "    -m memory:     Change the machine's memory size (in mb) (saved)"
    echo "    -r resolution: Change the machine's screen resolution (e.g. 1024x768) (saved)"
    echo "    -v port:       Which vnc port qemu will listen on (default $VNC_PORT)"
    echo "    -i path:       Mount the installer dvd from this path"
    echo "    -c size:       Create a new vm with a hard drive image of the specified size (e.g. 128G)"
    echo
    echo "Some options will be saved to the vm and re-used until changed."
    echo
    list_resolutions
}

function set_resolution {
    resolution=$1
    mount_point="$VM_DIRECTORY/clover_mount"
    config_plist="$mount_point/EFI/CLOVER/config.plist"

    mkdir -p "$mount_point"
    guestmount -a "$VM_DIRECTORY/Clover.qcow2" -m /dev/sda1 "$mount_point"
    sed -i "s/>[0-9][0-9][0-9]*x[0-9][0-9][0-9]*</>$resolution</g" "$config_plist"
    umount "$mount_point"
    sleep 1s
    rmdir "$mount_point"
}

function run_vm {
    vm_dir="$VM_DIRECTORY"
    firmware_dir="$SCRIPT_HOME"
    memory_kb=$MEMORY
    screen_res=$SCREEN_RESOLUTION
    vnc_port=$VNC_PORT
    installer_image="$INSTALLER_IMAGE"

    mac_hdd_image="${vm_dir}/mac_hdd.qcow"
    cpu_performance_options="+aes,+xsave,+avx,+xsaveopt,avx2,+smep"
    network_settings="user,id=user.0,hostfwd=tcp::5901-:5900 -device e1000-82545em,netdev=user.0"
    # network_settings="tap,id=net0,ifname=tap0,script=no,downscript=no -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27"

    echo "Running mac vm at $vm_dir with $memory_kb mb, screen $screen_res, vnc port $vnc_port"
    echo
    echo "REMEMBER: OVMF must also be set to $screen_res or else you'll get a garbled screen!"
    echo "          Steps to change OVMF resolution:"
    echo "          1. Press ESC during first boot splash screen (before Clover) to get into OVMF"
    echo "          2. Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> $screen_res"

    if [ "$installer_image" != "UNSET" ]; then
        installer_options="-device ide-drive,bus=ide.0,drive=MacDVD -drive id=MacDVD,if=none,snapshot=on,media=cdrom,file=$installer_image"
    else
        installer_options=
    fi

    qemu-system-x86_64 \
        -enable-kvm \
        -m $memory_kb \
        -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,${cpu_performance_options} \
        -machine pc-q35-2.9 \
        -smbios type=2 \
        -smp 4,cores=2 \
        -usb -device usb-kbd -device usb-tablet \
        -netdev ${network_settings} \
        -vnc $vnc_port \
        -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
        -drive if=pflash,format=raw,readonly,file="${firmware_dir}/OVMF_CODE-pure-efi.fd" \
        -drive if=pflash,format=raw,file="${vm_dir}/OVMF_VARS-pure-efi.fd" \
        -device ich9-intel-hda -device hda-duplex \
        -device ide-drive,bus=ide.2,drive=Clover \
        -drive id=Clover,if=none,snapshot=on,format=qcow2,file="${vm_dir}/Clover.qcow2" \
        -device ide-drive,bus=ide.1,drive=MacHDD \
        -drive id=MacHDD,if=none,file=${mac_hdd_image},format=qcow2 \
        ${installer_options}
}



# =======
# Options
# =======

OPTIND=1
while getopts "?m:r:v:i:c:" opt; do
    case "$opt" in
    \?)
        show_help
        exit 0
        ;;
    m)  MEMORY=$OPTARG
        ;;
    r)  SCREEN_RESOLUTION=$OPTARG
        ;;
    v)  VNC_PORT=$OPTARG
        ;;
    i)  INSTALLER_IMAGE=$OPTARG
        ;;
    c)  CREATE_NEW_DRIVE_SIZE=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [[ $# -ne 1 ]]; then
    show_help
    exit 1
fi

VM_DIRECTORY=$1
SETTINGS_FILE="${VM_DIRECTORY}/settings.sh"



# =======
# Program
# =======

set -eu

load_settings
validate_parameters
setup_vm
save_settings
set_resolution $SCREEN_RESOLUTION
run_vm
