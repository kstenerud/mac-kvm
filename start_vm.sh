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
WRITABLE_CLOVER=false
VNC_PORT=:0
MAC_HDD_IMAGE=$SCRIPT_DIR/mac_hdd.qcow

# Qemu won't start otherwise
export QEMU_AUDIO_DRV=alsa



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
    echo "Currently defined resolutions:"
    for i in $SCRIPT_DIR/Clover*; do
        resolution=$(echo $i | sed 's/.*Clover\([0-9]*x[0-9]*\).*/\1/')
        echo "    $resolution"
    done
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
    echo "    -c:        Make the Clover image writable for changing configuration (default $WRITABLE_CLOVER)"
    echo
    list_resolutions
}

function pre_run {
    if [ ! -f "${SCRIPT_DIR}/OVMF_VARS-pure-efi.fd" ]; then
        cp ${SCRIPT_DIR}/OVMF_VARS-pure-efi-1024x768.fd.template ${SCRIPT_DIR}/OVMF_VARS-pure-efi.fd
    fi
}

function run_vm {
    memory_kb=$1
    mac_hdd_image=$2
    screen_size=$3
    vnc_port=$4
    should_mount_installer=$5
    writable_clover=$6
    cpu_performance_options="+aes,+xsave,+avx,+xsaveopt,avx2,+smep"
    network_settings="user,id=user.0 -device e1000-82545em,netdev=user.0"
    # network_settings="tap,id=net0,ifname=tap0,script=no,downscript=no -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27"

    echo "Running mac vm with memory $memory_kb, screen $screen_size, vnc port $vnc_port, installer=$should_mount_installer, writable clover=$writable_clover"

    if [ "$should_mount_installer" = true ]; then
        installer_options="-device ide-drive,bus=ide.0,drive=MacDVD -drive id=MacDVD,if=none,snapshot=on,media=cdrom,file=./HighSierra.iso"
    else
        installer_options=
    fi

    if [ "$writable_clover" = false ]; then
        clover_options=,snapshot=on
    else
        clover_options=
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
        -drive id=Clover,if=none,format=qcow2,file=$SCRIPT_DIR/Clover${screen_size}.qcow2${clover_options} \
        -device ide-drive,bus=ide.1,drive=MacHDD \
        -drive id=MacHDD,if=none,file=${mac_hdd_image},format=qcow2 \
        ${installer_options}
}



# =======
# Options
# =======

OPTIND=1
while getopts "?m:h:s:v:ic" opt; do
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
    c)  WRITABLE_CLOVER=true
        ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift



# =======
# Program
# =======

set -eu

pre_run
run_vm $MEMORY $MAC_HDD_IMAGE $SCREEN_SIZE $VNC_PORT $SHOULD_MOUNT_INSTALLER $WRITABLE_CLOVER

