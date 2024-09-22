#!/bin/bash

# Kiểm tra quyền truy cập root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy với quyền root."
  exit 1
fi

# Cài đặt các gói cần thiết
echo "Cài đặt các gói cần thiết..."
dnf install epel-release -y
dnf install dante-server -y
dnf install iproute -y # Đảm bảo cài đặt iproute để lấy địa chỉ IP

# Lấy địa chỉ IPv4 của VPS
ipv4_address=$(hostname -I | awk '{print $1}')

# Lấy danh sách địa chỉ IPv6 có sẵn
ipv6_array=($(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+'))

# Đếm số lượng địa chỉ IPv6
valid_count=${#ipv6_array[@]}
echo "Số lượng địa chỉ IPv6 tìm thấy: $valid_count"

# In danh sách IPv6 ra màn hình
echo "Danh sách địa chỉ IPv6 đã lấy được:"
printf '%s\n' "${ipv6_array[@]}"

# Tạo file cấu hình Dante
config_file="/etc/danted.conf"
echo "Tạo file cấu hình Dante..."
cat <<EOL > $config_file
logoutput: /var/log/danted.log
socksmethod: username
user.privileged: root
user.unprivileged: nobody
client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
EOL

# Tạo proxy và danh sách thông tin đăng nhập
echo "Đang tạo proxy..."
output_file="proxy_list.txt"
rm -f $output_file

for ((i=0; i<valid_count; i++)); do
  ipv6="${ipv6_array[i]}"
  port=$((1080 + i)) # Bắt đầu từ port 1080
  user="user$i"
  pass="pass$RANDOM"

  # Cập nhật cấu hình cho mỗi proxy
  echo "internal: $ipv4_address port = $port" >> $config_file
  echo "external: $ipv6" >> $config_file

  # Xuất thông tin proxy
  echo "$ipv4_address:$port:$user:$pass" >> $output_file
done

# Tạo file dịch vụ cho Dante
service_file="/etc/systemd/system/danted.service"
echo "Tạo file dịch vụ cho Dante..."
cat <<EOL > $service_file
[Unit]
Description=Dante SOCKS Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/danted -f /etc/danted.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Khởi động lại dịch vụ Dante
echo "Khởi động lại dịch vụ Dante..."
systemctl daemon-reload
systemctl start danted
systemctl enable danted

# In danh sách proxy ra màn hình
echo "Hoàn thành! Danh sách proxy đã được lưu trong $output_file:"
cat $output_file
