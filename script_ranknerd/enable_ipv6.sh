#!/bin/bash

# Kiểm tra quyền truy cập root
if [[ $EUID -ne 0 ]]; then
   echo "Vui lòng chạy script này với quyền root."
   exit 1
fi

# Bật IPv6 trong sysctl
echo "Bật IPv6 trong sysctl..."
cat <<EOF >> /etc/sysctl.d/99-sysctl.conf
# Bật IPv6
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF

# Áp dụng các thay đổi sysctl
sysctl -p /etc/sysctl.d/99-sysctl.conf

# Kiểm tra trạng thái của IPv6
if [ -d /etc/sysconfig/network-scripts ]; then
    for file in /etc/sysconfig/network-scripts/ifcfg-*; do
        if grep -q 'IPV6INIT' "$file"; then
            echo "Cập nhật cấu hình IPv6 trong $file..."
            sed -i 's/IPV6INIT=no/IPV6INIT=yes/' "$file"
            sed -i 's/IPV6_AUTOCONF=no/IPV6_AUTOCONF=yes/' "$file"
        else
            echo "Cập nhật cấu hình IPv6 cho $file..."
            echo "IPV6INIT=yes" >> "$file"
            echo "IPV6_AUTOCONF=yes" >> "$file"
        fi
    done
else
    echo "Không tìm thấy thư mục /etc/sysconfig/network-scripts."
    exit 1
fi

# Khởi động lại dịch vụ mạng để áp dụng thay đổi
echo "Khởi động lại dịch vụ mạng..."
systemctl restart network

# Kiểm tra trạng thái IPv6
echo "Kiểm tra trạng thái IPv6..."
ip -6 addr show

echo "IPv6 đã được bật thành công!"