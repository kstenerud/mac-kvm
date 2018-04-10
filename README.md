High Sierra under KVM
=====================


Installing
----------

 1. Create High Sierra iso image called HighSierra.iso (or link to it)
 2. Create a hard drive image: qemu-img create -f qcow2 mac_hdd.qcow 128G
 3. ./start_vm.sh -i -s 1024x768
 4. Use VNC (default port 5900) to connect to the installer
 5. Complete the installation
 6. Shut down



Running
-------

    start_vm.sh -?
    start_vm.sh <options> &



Maintenance and Tweaks
----------------------

### Changing the Screen Resolution

Note: to get a list of supported resolutions, use ./start_vm.sh -?

  1. ./start_vm.sh -s [chosen resolution]
  2. Press ESC during early boot (before Clover screen) to get to OVMF menu
  3. Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> [chosen resolution]
  4. Save and reboot
  5. Make sure it boots without a scrambled screen. If it's scrambled, there's a resolution mismatch between Clover and OVMF.


### Adding a New Screen Resolution

Note: Only the resolutions listed in OVMF platform configuration are valid.

  1. cp Clover1024x768.qcow Clover[new resolution].qcow
  2. ./start_vm.sh -c -s 1024x768
  3. Press ESC during early boot (before Clover screen) to get to OVMF menu
  4. Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> 1024x768
  5. Save and reboot
  6. Boot, log in to the OS, and start a terminal
  7. sudo mkdir /Volumes/efi
  8. sudo mount -t msdos /dev/disk0s1 /Volumes/efi
  9. sudo vi /Volumes/efi/EFI/CLOVER/config.plist
 10. Change the resolution from 1024x768 to your new resolution
 11. Save the file
 12. Shutdown
 13. ./start_vm.sh -s [new resolution]
 14. Press ESC during early boot (before Clover screen) to get to OVMF menu
 15. Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> [new resolution]
 16. Save and reboot
 17. Make sure it boots without a scrambled screen. If it's scrambled, there's a resolution mismatch between Clover and OVMF.



### Clearing Free Space on the Mac Guest

    diskutil secureErase freespace 0 /Volumes/MacOS



### Compressing a QCOW Image on the Host

    mv mac_hdd.qcow mac_hdd-uncompacted.qcow
    qemu-img convert -O qcow2 -c mac_hdd-uncompacted.qcow mac_hdd.qcow
    rm mac_hdd-uncompacted.qcow



Notes
-----

Most of this is shamelessly stolen from https://github.com/kholia/OSX-KVM



License
-------

start_vm.sh is released under MIT license https://opensource.org/licenses/MIT

Everything else is someone else's work, and may have different licensing terms.
