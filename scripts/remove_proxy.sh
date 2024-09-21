#!/bin/bash

# Đường dẫn tới file xác thực và file cấu hình Squid
htpasswd_file="/etc/squid/squid_passwd"
squid_conf="/etc/squid/squid.conf"

# Dừng dịch vụ Squid
sudo systemctl stop squid

# Xóa file xác thực
if [ -f "$htpasswd_file" ]; then
    sudo rm -f "$htpasswd_file"
    echo "Đã xóa file xác thực: $htpasswd_file"
else
    echo "File xác thực không tồn tại."
fi

# Khôi phục lại cấu hình Squid gốc
if [ -f "$squid_conf.bak" ]; then
    sudo mv "$squid_conf.bak" "$squid_conf"
    echo "Đã khôi phục lại cấu hình Squid."
else
    echo "File cấu hình gốc không tồn tại."
fi

# Khởi động lại dịch vụ Squid
sudo systemctl start squid

# Xóa cổng đã mở trong firewall
for ((i=0; i<100; i++)); do
    port=$((8080 + i))
    sudo firewall-cmd --remove-port=$port/tcp --permanent
done

# Reload firewall để áp dụng thay đổi
sudo firewall-cmd --reload

echo "Đã xóa tất cả cấu hình proxy và quy tắc firewall."
