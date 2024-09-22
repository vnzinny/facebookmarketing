#!/bin/bash

# Dừng dịch vụ 3proxy nếu đang chạy
echo "Dừng dịch vụ 3proxy cũ..."
if ! systemctl stop 3proxy; then
    echo "Không thể dừng dịch vụ 3proxy."
    exit 1
fi

# Tắt tường lửa (firewalld)
echo "Tắt tường lửa..."
if ! systemctl stop firewalld; then
    echo "Không thể tắt tường lửa."
    exit 1
fi

# Gỡ bỏ tường lửa khởi động cùng hệ thống
echo "Vô hiệu hóa tường lửa khởi động cùng hệ thống..."
systemctl disable firewalld

# Cài đặt các gói cần thiết cho biên dịch
echo "Cài đặt các gói cần thiết..."
yum install -y epel-release gcc make git

# Tải mã nguồn 3proxy phiên bản 0.9.3
echo "Tải mã nguồn 3proxy phiên bản 0.9.3..."
cd /usr/local/src
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy
git checkout 0.9.3

# Biên dịch 3proxy
echo "Biên dịch 3proxy..."
make -f Makefile.Linux

# Cài đặt 3proxy
echo "Cài đặt 3proxy..."
mkdir -p /usr/local/etc/3proxy/bin
cp /usr/local/src/3proxy /usr/local/etc/3proxy/bin
cp /usr/local/src/3proxy/scripts/init.d/3proxy.sh /etc/init.d/3proxy

# Thiết lập khởi động tự động cho 3proxy
echo "Thiết lập khởi động tự động cho 3proxy..."
chkconfig 3proxy on

# Xóa file cấu hình cũ nếu tồn tại
CONFIG_FILE="/etc/3proxy.cfg"
if [ -f "$CONFIG_FILE" ]; then
    echo "Xóa cấu hình cũ..."
    rm -f "$CONFIG_FILE"
fi

# Xóa log cũ nếu tồn tại
LOG_FILE="/var/log/3proxy/3proxy.log"
if [ -f "$LOG_FILE" ]; then
    echo "Xóa log cũ..."
    rm -f "$LOG_FILE"
fi

# Địa chỉ IPv4 của VPS
VPS_IPV4=$(curl -s ifconfig.me)
echo "IPv4 của VPS: $VPS_IPV4"

# Lấy danh sách địa chỉ IPv6, loại bỏ phần CIDR
IPV6_LIST=$(ip -6 addr show | grep 'inet6' | awk '{print $2}' | grep -v '::1' | cut -d/ -f1)
echo "Danh sách địa chỉ IPv6: $IPV6_LIST"

# Biến để lưu danh sách proxy
PROXY_LIST=()
PORT_START=8080
count=0

# Tạo file cấu hình cho 3proxy
echo "nserver 8.8.8.8" > "$CONFIG_FILE"
echo "nserver 8.8.4.4" >> "$CONFIG_FILE"
echo "nserver 2001:4860:4860::8888" >> "$CONFIG_FILE"  # DNS IPv6
echo "nserver 2001:4860:4860::8844" >> "$CONFIG_FILE"  # DNS IPv6
echo "timeouts 1 5 30 60 180 1800 15 60" >> "$CONFIG_FILE"
echo "daemon" >> "$CONFIG_FILE"
echo "log /var/log/3proxy/3proxy.log D" >> "$CONFIG_FILE"
echo "auth strong" >> "$CONFIG_FILE"

# Tạo proxy từ IPv6
for IPV6 in $IPV6_LIST; do
    PORT=$((PORT_START + count))
    USER="user$count"
    PASS=$(openssl rand -base64 12)

    # Thêm thông tin vào danh sách proxy
    PROXY_LIST+=("$VPS_IPV4:$PORT:$USER:$PASS")

    # Thêm cấu hình cho 3proxy
    echo "users $USER:CL:$PASS" >> "$CONFIG_FILE"
    echo "proxy -6 -n -a -i$IPV6 -e$IPV6 -p$PORT" >> "$CONFIG_FILE"
    echo "allow $USER" >> "$CONFIG_FILE"
    echo "maxconn 100" >> "$CONFIG_FILE"

    # Tăng biến đếm
    count=$((count + 1))
done

# Khởi động dịch vụ 3proxy
echo "Khởi động lại dịch vụ 3proxy..."
if ! systemctl start 3proxy; then
    echo "Không thể khởi động lại dịch vụ 3proxy."
    exit 1
fi

# In danh sách proxy
echo "Danh sách proxy:"
for PROXY in "${PROXY_LIST[@]}"; do
    echo "$PROXY"
done

# Thông báo kết thúc
echo "Cấu hình 3proxy đã hoàn tất."
