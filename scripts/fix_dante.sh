#!/bin/bash

# Đường dẫn tới file cấu hình Dante
CONFIG_FILE="/etc/sockd.conf"
LOG_FILE="/var/log/sockd.log"

# Sao lưu file cấu hình hiện tại trước khi chỉnh sửa
cp $CONFIG_FILE ${CONFIG_FILE}.bak

# Ghi đè cấu hình mới
cat > $CONFIG_FILE << EOL
logoutput: $LOG_FILE

internal: eth0 port = 1080
external: eth0

# Quy tắc cho client - thêm phương pháp xác thực bằng tên người dùng/mật khẩu
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# Quy tắc cho server SOCKS - thêm phương pháp xác thực
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    method: username
    log: connect disconnect
}

# Đặt quyền user cho Dante
user.privileged: root
user.unprivileged: nobody

# Quyền cho các file được tạo
user.libwrap: nobody
EOL

# Khởi động lại dịch vụ sockd
echo "Khởi động lại dịch vụ Dante..."
systemctl restart sockd

# Kiểm tra trạng thái dịch vụ
echo "Kiểm tra trạng thái dịch vụ..."
systemctl status sockd

# Kiểm tra log nếu có lỗi
echo "Kiểm tra log tại $LOG_FILE"
cat $LOG_FILE | tail -n 20
