#!/bin/bash

# Đường dẫn tới file cấu hình và log
CONFIG_FILE="/etc/sockd.conf"
LOG_FILE="/var/log/sockd.log"
SERVICE_NAME="sockd"

# Dừng dịch vụ sockd nếu đang chạy
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "Dừng dịch vụ $SERVICE_NAME..."
    systemctl stop $SERVICE_NAME
fi

# Xóa file cấu hình
if [ -f $CONFIG_FILE ]; then
    echo "Xóa file cấu hình $CONFIG_FILE..."
    rm -f $CONFIG_FILE
fi

# Xóa file log
if [ -f $LOG_FILE ]; then
    echo "Xóa file log $LOG_FILE..."
    rm -f $LOG_FILE
fi

# Gỡ bỏ gói cài đặt dante-server
echo "Gỡ bỏ gói dante-server..."
dnf remove -y dante-server

# Xóa dịch vụ systemd
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    echo "Xóa dịch vụ systemd $SERVICE_NAME..."
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
fi

echo "Gỡ bỏ hoàn tất."
