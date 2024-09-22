#!/bin/bash

# Đường dẫn đến tệp cấu hình Squid và tệp xác thực
squid_conf="/etc/squid/squid.conf"
htpasswd_file="/etc/squid/squid_passwd"

# Kiểm tra xem có tệp sao lưu cấu hình không
if [ -f "$squid_conf.bak" ]; then
    echo "Khôi phục tệp cấu hình Squid từ bản sao lưu..."
    mv $squid_conf.bak $squid_conf
else
    echo "Không tìm thấy tệp sao lưu. Khôi phục thủ công cấu hình."
fi

# Xóa tệp xác thực nếu có
if [ -f "$htpasswd_file" ]; then
    echo "Xóa tệp xác thực..."
    rm -f $htpasswd_file
else
    echo "Không tìm thấy tệp xác thực."
fi

# Khởi động lại Squid để áp dụng cấu hình mới
echo "Khởi động lại dịch vụ Squid..."
sudo systemctl restart squid

# Tắt Squid khỏi khởi động cùng hệ thống (nếu cần)
sudo systemctl disable squid

echo "Hoàn tất gỡ bỏ cấu hình proxy."
