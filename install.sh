#!/bin/bash

append_if_does_not_exist() {
  string=$1
  file=$2
  if ! grep -q "$string" "$file"; then
    echo "$string" >> "$file"
    echo "Added $string to $file"
  fi
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if [ "$1" == "-r" ]; then
  # Remove the service
  systemctl disable usb-cdc-gadget
  rm -f /etc/systemd/system/usb-cdc-gadget.service
  systemctl daemon-reload
  
  # Remove the enable script
  rm -f /usr/local/bin/enable_usb_cdc_gadget.sh
  
  # Remove dnsmasq
  rm -f /etc/dnsmasq.d/usb
  systemctl stop dnsmasq
  echo ""
  apt purge dnsmasq -y
  echo ""

  # Remove interface
  rm -f /etc/network/interfaces.d/usb0

  # Remove kernel modules
  sed -i '${/libcomposite/d}' /etc/modules
  sed -i '${s/ modules-load=dwc2//}' /boot/cmdline.txt 
  sed -i '${/dtoverlay=dwc2/d}' /boot/config.txt

  echo "Uninstallation has succeeded. Please reboot."
  exit 0
fi

# Add and load the kernel modules necessary for the gadget to function
append_if_does_not_exist "dtoverlay=dwc2" "/boot/config.txt"
# Get rid of the new line
printf "%s" "$(< /boot/cmdline.txt)" > /boot/cmdline.txt
append_if_does_not_exist " modules-load=dwc2" "/boot/cmdline.txt"
append_if_does_not_exist "libcomposite" "/etc/modules"

# Give the device a static IP
interface='auto usb0
allow-hotplug usb0
iface usb0 inet static
address 192.168.53.1
netmask 255.255.255.248'
echo "$interface" > /etc/network/interfaces.d/usb0
echo "Set up a static IP: 192.168.53.1"

# Set up a DHCP server using dnsmasq because it is quick and simple
echo ""
apt install dnsmasq -y
echo ""
config='dhcp-authoritative
dhcp-rapid-commit
interface=usb0
bind-interfaces
port=0
dhcp-option=3,192.168.53.1
dhcp-range=192.168.53.1,192.168.53.6,255.255.255.248,24h
leasefile-ro'
echo "$config" > /etc/dnsmasq.d/usb
echo "Set up a DHCP server using dnsmasq 192.168.53.1-192.168.53.6"

# Create the script that will enable the gadget on every boot
script='#!/bin/bash

cd /sys/kernel/config/usb_gadget/ || exit
mkdir -p orange-network
cd orange-network || exit

# Linux Foundation
echo 0x1d6b > idVendor
# Multifunction Composite Gadget
echo 0x0104 > idProduct
# v1.0.0
echo 0x0100 > bcdDevice
# USB2
echo 0x0200 > bcdUSB

# US English
mkdir -p strings/0x409
# Configuration Strings
echo "0" > strings/0x409/serialnumber
echo "Orange_Murker" > strings/0x409/manufacturer
echo "Orange_Murker Network Device" > strings/0x409/product

# Create config directory
mkdir -p configs/c.1/strings/0x409
echo "Conf 1" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

# Create functions directory
mkdir -p functions/ecm.usb0

# I just generated some random LAA MAC addresses. Not that it matters too much.
# The MAC address of the Pi
echo "4A:4F:10:4B:5E:0A" > functions/ecm.usb0/host_addr
# The MAC address that the device connected over USB gets
echo "52:4E:0A:6B:B6:D9" > functions/ecm.usb0/dev_addr

# Link the functions to the config
ln -s functions/ecm.usb0 configs/c.1/

ls /sys/class/udc > UDC

udevadm settle -t 5 || :
ifup usb0
systemctl restart dnsmasq'
echo "$script" > /usr/local/bin/enable_usb_cdc_gadget.sh
echo "Created the start script"

# Set up the systemd service
service='[Unit]
Description=Used To Enable USB CDC Gadget
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/enable_usb_cdc_gadget.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target'
echo "$service" > /etc/systemd/system/usb-cdc-gadget.service
echo "Created the systemd service"

systemctl daemon-reload && systemctl enable usb-cdc-gadget

echo "Installation has succeeded. Please reboot."
exit 0
