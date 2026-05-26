# Hardware Sideload Reference

Use this when trying to put a built Passport Prime app onto a physical Passport Prime from a Windows-controlled VM.

## Version Reality

Foundation reported during SDK v0.4 beta work:

```text
SDK v0.4 can build signed apps but cannot install them on hardware.
Hardware install/sideload-launch requires newer SDK/firmware with an apps menu,
developer certificate installation, and sideload support.
```

Therefore, successful copy to Passport Prime storage may be the furthest possible result on public SDK/firmware.

## Passport Prime USB In VirtualBox

From Windows:

```powershell
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' list usbhost
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' controlvm <vm-name> usbattach <usb-uuid>
```

Observed Passport Prime identifiers:

```text
VendorId: 0x1307
ProductId: 0x0165
Manufacturer: Foundation Devices, Inc.
Product: Passport Prime
Volume label: AIRLOCK
```

Inside Ubuntu:

```bash
lsusb
lsblk -f
sudo mkdir -p /mnt/prime
sudo mount -t vfat -o uid=$(id -u),gid=$(id -g) /dev/sdX /mnt/prime
```

## Copy-Only Sideload

Use copy-only mode when firmware install/launch support is unknown:

```bash
foundation sideload --mount-path /mnt/prime --no-run
```

Expected copied files:

```text
/mnt/prime/keyos/apps/<app-id>/app.elf
/mnt/prime/keyos/apps/<app-id>/manifest.json
```

Unmount cleanly:

```bash
sync
sudo umount /mnt/prime
```

Detach USB from the VM before asking Windows or Passport Prime to inspect storage.

## Interpreting Results

Copy succeeded, app not launchable:

- Not necessarily an app/build failure.
- AIRLOCK/filesystem is a transfer surface, not an app launcher.
- Tapping `app.elf` in Files is not expected to run the app unless Foundation documents that behavior.

Ask Foundation:

```text
Which public SDK/firmware version supports installing a signed developer app on Passport Prime,
and what exact on-device menu flow should consume /keyos/apps/<app-id>?
```

## Report Template

```text
SDK version:
Passport Prime firmware version:
Host setup:
Command run:
Mount path:
Copied files present:
On-device result:
Question/blocker:
```
