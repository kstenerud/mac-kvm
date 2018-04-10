High Sierra under KVM
=====================


Installing
----------

 1. Create High Sierra iso image called HighSierra.iso (or link to it)
 2. Create a hard drive image: qemu-img create -f qcow2 mac_hdd.qcow 128G
 3. ./start_vm.sh -i
 4. Use VNC (default port 5900) to connect to the installer
 5. Complete the installation
 6. Shut down



Running
-------

    start_vm.sh -?
    start_vm.sh <options> &



Maintenance and Tweaks
----------------------

### Adding a New Screen Resolution

Note: Only the resolutions listed in OVMF platform configuration are valid.

  1. cp Clover1024x768.qcow Clover<new resolution>.qcow
  2. cp OVMF_VARS-pure-efi-1024x768.fd OVMF_VARS-pure-efi-<new resolution>.fd
  2. ./start_vm.sh -c -s <new resolution>
  4. Boot (screen will be 1024x768), log in to the OS, start a terminal
  5. sudo mkdir /Volumes/efi
  6. sudo mount -t msdos /dev/disk0s1 /Volumes/efi
  7. sudo vi /Volumes/efi/EFI/CLOVER/config.plist
  8. Change the resolution from 1024x768 to <new resolution>
  9. Save the file
 10. Reboot
 11. Press ESC during early boot (before Clover screen) to get to OVMF menu
 12. Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> <new resolution>
 13. Save
 14. Reboot
 15. Make sure it boots without a scrambled screen.
 16. Shut down



### Clearing Free Space on the Mac Guest

    diskutil secureErase freespace 0 /Volumes/MacOS



### Compressing a QCOW Image on the Host

    mv mac_hdd.qcow mac_hdd-uncompacted.qcow
    qemu-img convert -O qcow2 -c mac_hdd-uncompacted.qcow mac_hdd.qcow
    rm mac_hdd-uncompacted.qcow

