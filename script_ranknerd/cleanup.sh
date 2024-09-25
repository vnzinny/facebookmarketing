#!/bin/bash

WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"

# Dừng dịch vụ 3proxy
echo "Stopping 3proxy..."
pkill 3proxy

# Xóa tệp cấu hình 3proxy
echo "Removing 3proxy configuration..."
rm -f /usr/local/etc/3proxy/3proxy.cfg
rm -rf /usr/local/etc/3proxy/{bin,logs,stat}

# Xóa tệp tin dữ liệu và proxy
echo "Removing data files..."
rm -f $WORKDATA
rm -f $WORKDIR/proxy.txt
rm -f $WORKDIR/boot_iptables.sh
rm -f $WORKDIR/boot_ifconfig.sh

# Xóa quy tắc iptables
echo "Removing iptables rules..."
iptables -F

# Xóa rc.local service
echo "Disabling and removing rc.local service..."
systemctl stop rc-local
systemctl disable rc-local
rm -f /etc/systemd/system/rc-local.service
rm -f /etc/rc.d/rc.local

# Gỡ cài đặt 3proxy nếu cần thiết
echo "Removing 3proxy package if installed..."
# Bạn có thể thay đổi lệnh sau nếu bạn đã cài đặt 3proxy theo cách khác
# sudo dnf remove 3proxy -y

echo "Cleanup completed."