#!/bin/bash

# Kiểm tra quyền truy cập root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy với quyền root."
  exit 1
fi

# Cài đặt EPEL repository và Dante
echo "Cài đặt EPEL repository và Dante..."
dnf install epel-release -y
dnf install dante-server -y

# Nhập địa chỉ IPv6
echo "Nhập 100 địa chỉ IPv6 (mỗi địa chỉ trên một dòng):"
readarray -t ipv6_array

# Kiểm tra số lượng địa chỉ IPv6
if [ "${#ipv6_array[@]}" -ne 100 ]; then
  echo "Bạn cần nhập đúng 100 địa chỉ IPv6."
  exit 1
fi

# Lấy địa chỉ IPv4 của VPS
ipv4_address=$(hostname -I | awk '{print $1}')

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

for ((i=0; i<100; i++)); do
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

# Khởi động lại dịch vụ Dante
echo "Khởi động lại dịch vụ Dante..."
systemctl restart danted

echo "Hoàn thành! Danh sách proxy đã được lưu trong $output_file."
