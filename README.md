High Sierra under KVM
=====================

This script sets up QEMU to boot a MacOS High Sierra install disk or hard drive.
You can connect to QEMU's VNC server on port 5900, or to the virtual mac's screen sharing server (if enabled) on forwarded port 5901.



Creating a New Virtual Mac
--------------------------

The following will create a new mac vm in /path/to/vm/dir containing a 64 gb hdd image.
If the directory doesn't exist yet, it will be created.

  1. start_macos_vm.sh -i /path/to/HighSierra.iso -c 64g /path/to/vm/dir
  2. Use VNC (default port 5900) to connect to the installer via QEMU's VNC service
  3. Run Disk Utility
  4. Select View (top left corner gadget) -> Show All Devices
  5. Select your virtual drive (bottom QEMU HARDDISK MEDIA drive)
  6. Erase your virtual drive, naming it "MacOS" (Clover's config.plist is set to boot "MacOS" by default)
  7. Quit Disk Utility
  8. Run the OS installer

After creating and installing the vm, you don't need the installer anymore, so you can just run it like this:

    start_macos_vm.sh /path/to/vm/dir



Running
-------

    start_macos_vm.sh -?
    start_macos_vm.sh [options] /path/to/mac/vm/container/directory &

The script expects a hdd image called mac_hdd.qcow in the vm container directory, which it can create if you use the -c option.
All other files it needs will be added to the container directory automatically.
Settings will be saved to the vm directory.


### Notes About Screen Resolutions

In order for the screen to display correctly, both OVMF and Clover must be in agreement as to what resolution to show. This script can handle Clover, but you must set the resolution in OVMF yourself:

  1. start_macos_vm.sh [options] -r [chosen resolution] /path/to/mac/vm/container/directory
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



Troubleshooting
---------------

### Graphics

Some apps may not display properly because they try to use hardware acceleration (for examle, Chrome and Skype). Try to disable hardware acceleration in programs if you can  (Chrome's hardware acceleration setting is under advanced settings, but it's difficult to get to because the settings page uses hardware acceleration :P).



Notes
-----

Most of this is shamelessly stolen from https://github.com/kholia/OSX-KVM



License
-------

start_macos_vm.sh is released under MIT license https://opensource.org/licenses/MIT

Everything else is someone else's work, and may have different licensing terms.
