---
# dotfiles-c6gu
title: Recover AMD USB controller stuck after runtime suspend
status: todo
type: bug
tags:
    - discovered
created_at: 2026-10-09T22:39:01Z
updated_at: 2026-10-09T22:39:01Z
---

Bluetooth recovery revealed a USB-controller failure, not just rfkill.

Evidence on interplanetary:
- Bluetooth dongle Realtek 2b89:6275 is attached below AMD 600 Series USB controller 0000:11:00.0 (1022:43f7), USB buses 1/2.
- Oct 4: xHC error in resume, USBSTS 0x411, Reinit.
- Oct 6: Clearing Run/Stop bit failed -110; xhci_pci_suspend and hcd_pci_runtime_suspend failed -110.
- Before recovery: PCI power/control=auto and runtime_status=error. Bluetooth adapter Powered=no, off-blocked.
- Cleared rfkill successfully, but BlueZ and direct btmgmt power-on still failed (status 0x03).
- Restarted BlueZ; tried adapter driver rebind, USB reauthorization/reset and Bluetooth-only hub rebind. Kernel returned -16 / xHC not accessible.
- Set the affected PCI controller power/control=on, tried xhci rebind and supported PCI bus reset (bus 11 contains only this controller). Controller still cannot halt/init: -110.

Current state: Bluetooth service is active, but affected PCI controller failed to rebind and no Bluetooth controller is registered. Other USB controllers (keyboard/mouse/audio) were not reset. No reboot or shutdown was performed. Needs user-managed cold shutdown/power cycle; adapter unplug alone may not recover its parent controller.

Per user approval, added a host-scoped udev rule in hosts/interplanetary/default.nix setting power/control=on only for PCI controller 0000:11:00.0 on add/bind events. Cost: increased idle power on its USB subtree. No reboot, shutdown, or further controller reset was performed. Recovery and recurrence verification remain pending the user's cold power cycle; no unconditional rfkill unblocking was added.
