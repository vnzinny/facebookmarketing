#!/bin/bash

# Dừng tất cả các tiến trình socat đang chạy
pkill socat

# Xóa file xác thực
htpasswd_file="/etc/proxy_passwd"

if [ -f "$htpasswd_file" ]; then
    rm -f "$htpasswd_file"
    echo "Đã xóa file xác thực: $htpasswd_file"
else
    echo "Không tìm thấy file xác thực."
fi

# Dừng dịch vụ Apache
sudo systemctl stop httpd
echo "Dịch vụ Apache đã dừng."

echo "Đã xóa tất cả các proxy và file xác thực."
