#!/bin/bash

# Đường dẫn tới file cấu hình Dante
CONFIG_FILE="/etc/sockd.conf"
LOG_FILE="/var/log/sockd.log"

# Sao lưu file cấu hình hiện tại trước khi chỉnh sửa
cp $CONFIG_FILE ${CONFIG_FILE}.bak

# Ghi đè cấu hình mới vào file cấu hình Dante
cat > $CONFIG_FILE << EOL
logoutput: $LOG_FILE

internal: eth0 port = 1080
external: eth0

# Quy tắc cho client - áp dụng cho tất cả các địa chỉ
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# Quy tắc cho server SOCKS - thêm phương pháp xác thực
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    socksmethod: username
    log: connect disconnect
}

# Đặt quyền user cho Dante
user.privileged: root
user.notprivileged: nobody
user.libwrap: nobody
EOL

# Kiểm tra lỗi cú pháp trong file cấu hình
echo "Kiểm tra file cấu hình..."
if sockd -f $CONFIG_FILE -N; then
    echo "Cấu hình hợp lệ."
else
    echo "Cấu hình có lỗi, kiểm tra log để biết thêm thông tin."
    exit 1
fi

# Khởi động lại dịch vụ sockd
echo "Khởi động lại dịch vụ Dante..."
systemctl restart sockd

# Kiểm tra trạng thái dịch vụ
echo "Kiểm tra trạng thái dịch vụ..."
systemctl status sockd

# Hiển thị log
echo "Kiểm tra log tại $LOG_FILE"
cat $LOG_FILE | tail -n 20
