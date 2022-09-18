# USB ECM Gadget
Simple installation script to get your device to show up as a network card.

---

### Compatibility

Should work on any OTG-capable system notables examples of which include:
* Raspberry Pi 4
* All Models of Raspberry Pi Zero

---

### Usage Instructions

This script requires pretty much no user intervention.

#### To install:
1. `curl -O https://raw.githubusercontent.com/Orange-Murker/usb-ecm-gadget/main/install.sh && sudo chmod +x install.sh && sudo ./install.sh`
2. `sudo reboot`
3. Enjoy. Your device will be available at `192.i68.53.1`

#### To uninstall:
1. `curl -O https://raw.githubusercontent.com/Orange-Murker/usb-ecm-gadget/main/install.sh && sudo chmod +x install.sh && sudo ./install.sh -r`
2. `sudo reboot`

---

### Implementation Details

This was accomplished by configuring the `usb_f_ecm.ko` kernel module using `configfs`

`dnsmasq` acts as a DCHP server offering IP addresses from this range `192.168.53.2-192.168.53.6`
 
 Default DNS configuration on the system remains unchanged.
