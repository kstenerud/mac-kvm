High Sierra under KVM
=====================

This script sets up QEMU to boot a MacOS High Sierra install disk or hard drive.
You can connect to QEMU's VNC server on port 5900, or to the virtual mac's screen sharing server (if enabled) on forwarded port 5901.



Assumptions
-----------

This script makes certain assumptions about your environment:

 1. All disk images are in the current directory (or symlinked from there).
 2. The hard drive image is called mac_hdd.qcow
 3. The install disk is called HighSierra.iso



Installing
----------

  1. Create High Sierra iso image called HighSierra.iso (or link to it)
  2. Create a hard drive image: qemu-img create -f qcow2 mac_hdd.qcow 128G
  3. Start the VM in installer mode with 1024x768 screen size: ./start_vm.sh -i -s 1024x768
  4. Use VNC (default port 5900) to connect to the installer via qemu's VNC service
  5. Run Disk Utility
  6. Show all drives (top left corner gadget)
  7. Select your virtual drive
  8. Erase your virtual drive, naming it "MacOS" (Clover's config.plist is set to boot "MacOS" by default)
  9. Quit Disk Utility
 10. Run the OS installer



Running
-------

    start_vm.sh -?
    start_vm.sh <options> &


### Notes About Screen Resolutions

In order for the screen to display correctly, both OVMF and Clover must be in agreement as to what resolution to show. This script can handle Clover, but you must set the resolution in OVMF yourself:

  1. ./start_vm.sh -s [chosen resolution]
  2. Press ESC during early boot (before Clover screen) to get to the OVMF menu
  3. Navigate: Device Manager -> OVMF Platform Configuration -> Change Preferred Resolution for Next Boot -> [chosen resolution]
  4. Save and reboot
  5. Make sure it boots properly. If the screen is garbled, there's a resolution mismatch between Clover and OVMF.



Maintenance and Tweaks
----------------------


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
