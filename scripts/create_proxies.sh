#!/bin/bash

# Cài đặt 3proxy nếu chưa cài
yum install -y epel-release
yum install -y 3proxy

# Địa chỉ IPv4 của VPS
VPS_IPV4=$(curl -s ifconfig.me)
echo "IPv4 của VPS: $VPS_IPV4"

# Lấy danh sách địa chỉ IPv6
IPV6_LIST=$(ip -6 addr show | grep 'inet6' | awk '{print $2}' | grep -v '::1')
echo "Danh sách địa chỉ IPv6: $IPV6_LIST"

# Biến để lưu danh sách proxy
PROXY_LIST=()
PORT_START=8080
count=0

# Tạo file cấu hình cho 3proxy
CONFIG_FILE="/etc/3proxy.cfg"
echo "nserver 8.8.8.8" > $CONFIG_FILE
echo "auth strong" >> $CONFIG_FILE
echo "allow *" >> $CONFIG_FILE

# Tạo proxy từ IPv6
for IPV6 in $IPV6_LIST; do
    PORT=$((PORT_START + count))
    USER="user$count"
    PASS=$(openssl rand -base64 12)

    # Thêm thông tin vào danh sách proxy
    PROXY_LIST+=("$VPS_IPV4:$PORT:$USER:$PASS")

    # Thêm cấu hình cho 3proxy
    echo "proxy -6 -n -a -p$PORT -u $USER -p$PASS" >> $CONFIG_FILE

    # Tăng biến đếm
    count=$((count + 1))
done

# Cấp quyền cho file cấu hình
chmod 600 $CONFIG_FILE

# Khởi động dịch vụ 3proxy
systemctl start 3proxy
systemctl enable 3proxy

# In danh sách proxy
echo "Danh sách proxy:"
for PROXY in "${PROXY_LIST[@]}"; do
    echo "$PROXY"
done
