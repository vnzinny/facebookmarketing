#!/bin/bash

# Dừng dịch vụ 3proxy nếu nó đang chạy
sudo systemctl stop 3proxy

# Xóa gói 3proxy
sudo apt-get remove --purge 3proxy -y

# Xóa các tệp cấu hình (nếu có)
sudo rm -rf /etc/3proxy
sudo rm -f /etc/systemd/system/3proxy.service

# Cập nhật danh sách gói
sudo apt-get autoremove -y
sudo apt-get clean

echo "Đã gỡ bỏ hoàn toàn 3proxy và các cấu hình liên quan."
