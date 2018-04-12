#!/bin/bash

# Shamelessly stolen from https://github.com/kholia/OSX-KVM/blob/master/boot-macOS-HS.sh
#
# Create drive image:   qemu-img create -f qcow2 mac_hdd.qcow 128G
# Compact inside guest: diskutil secureErase freespace 0 /Volumes/MacOS
# Compact on host:      qemu-img convert -O qcow2 -c uncompacted.qcow compacted.qcow

SCRIPT_DIR=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")



# =====================
# Default Configuration
# =====================

MEMORY=3072
SCREEN_SIZE=1600x900
SHOULD_MOUNT_INSTALLER=false
VNC_PORT=:0
MAC_HDD_IMAGE=$SCRIPT_DIR/mac_hdd.qcow

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
    if [ $(is_valid_resolution "$SCREEN_SIZE") != "true" ]; then
        echo "$SCREEN_SIZE is not a valid resolution."
        list_resolutions
        exit 1
    fi
}

function create_from_template {
    template_file=$1
    destination_file=$2

    if [ ! -f "$destination_file" ]; then
        cp "$template_file" "$destination_file"
    fi
}

function setup_vm {
    create_from_template "${SCRIPT_DIR}/Clover-1024x768.qcow2.template" "${SCRIPT_DIR}/Clover.qcow2"
    create_from_template "${SCRIPT_DIR}/OVMF_VARS-pure-efi-1024x768.fd.template" "${SCRIPT_DIR}/OVMF_VARS-pure-efi.fd"
}

function show_help {
    echo "Run High Sierra in qemu"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "    -?:        Show this help screen."
    echo "    -m memory: How much memory to allocate in kb (default $MEMORY)"
    echo "    -h image:  The Mac HDD image to use (default $MAC_HDD_IMAGE)"
    echo "    -s size:   What screen size to use (default $SCREEN_SIZE)"
    echo "    -v port:   Which vnc port qemu will listen on (default $VNC_PORT)"
    echo "    -i:        Mount the installer dvd (default $SHOULD_MOUNT_INSTALLER)"
    echo
    list_resolutions
}

function set_resolution {
    resolution=$1
    mount_point="$SCRIPT_DIR/clover_mount"
    config_plist="$mount_point/EFI/CLOVER/config.plist"

    mkdir -p "$mount_point"
    guestmount -a "$SCRIPT_DIR/Clover.qcow2" -m /dev/sda1 "$mount_point"
    sed -i "s/>[0-9][0-9][0-9]*x[0-9][0-9][0-9]*</>$resolution</g" "$config_plist"
    umount "$mount_point"
    sleep 1s
    rmdir "$mount_point"
}

function run_vm {
    memory_kb=$1
    mac_hdd_image=$2
    screen_size=$3
    vnc_port=$4
    should_mount_installer=$5
    cpu_performance_options="+aes,+xsave,+avx,+xsaveopt,avx2,+smep"
    network_settings="user,id=user.0,hostfwd=tcp::5901-:5900 -device e1000-82545em,netdev=user.0"
    # network_settings="tap,id=net0,ifname=tap0,script=no,downscript=no -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27"

    echo "Running mac vm with memory $memory_kb, screen $screen_size, vnc port $vnc_port, installer=$should_mount_installer"
    echo
    echo "IMPORTANT: Remember that OVMF must also be set to $screen_size or else you'll get a garbled screen!"
    echo "           Press ESC during first boot splash screen (before Clover) to get into OVMF, then:"
    echo "           Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> $screen_size"

    if [ "$should_mount_installer" = true ]; then
        installer_options="-device ide-drive,bus=ide.0,drive=MacDVD -drive id=MacDVD,if=none,snapshot=on,media=cdrom,file=./HighSierra.iso"
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
        -drive if=pflash,format=raw,readonly,file=${SCRIPT_DIR}/OVMF_CODE-pure-efi.fd \
        -drive if=pflash,format=raw,file=${SCRIPT_DIR}/OVMF_VARS-pure-efi.fd \
        -device ich9-intel-hda -device hda-duplex \
        -device ide-drive,bus=ide.2,drive=Clover \
        -drive id=Clover,if=none,snapshot=on,format=qcow2,file=$SCRIPT_DIR/Clover.qcow2 \
        -device ide-drive,bus=ide.1,drive=MacHDD \
        -drive id=MacHDD,if=none,file=${mac_hdd_image},format=qcow2 \
        ${installer_options}
}



# =======
# Options
# =======

OPTIND=1
while getopts "?m:h:s:v:i" opt; do
    case "$opt" in
    \?)
        show_help
        exit 0
        ;;
    m)  MEMORY=$OPTARG
        ;;
    h)  MAC_HDD_IMAGE=$OPTARG
        ;;
    s)  SCREEN_SIZE=$OPTARG
        ;;
    v)  VNC_PORT=$OPTARG
        ;;
    i)  SHOULD_MOUNT_INSTALLER=true
        ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift



# =======
# Program
# =======

set -eu

validate_parameters
setup_vm
set_resolution $SCREEN_SIZE
run_vm $MEMORY $MAC_HDD_IMAGE $SCREEN_SIZE $VNC_PORT $SHOULD_MOUNT_INSTALLER
