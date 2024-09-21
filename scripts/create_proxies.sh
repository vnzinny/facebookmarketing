#!/bin/bash

# Lấy địa chỉ IPv4 của VPS
ipv4_address=$(hostname -I | awk '{print $1}')

# Đọc 100 địa chỉ IPv6 từ người dùng
echo "Nhập 100 địa chỉ IPv6 (mỗi địa chỉ trên một dòng):"
ipv6_addresses=()

for ((i=0; i<100; i++)); do
    read -p "IPv6 $((i+1)): " ipv6
    ipv6_addresses+=("$ipv6")
done

# Tạo file xác thực cho Apache
htpasswd_file="/etc/proxy_passwd"
touch $htpasswd_file

# Tạo các proxy
for ((i=0; i<100; i++)); do
    ipv6="${ipv6_addresses[i]}"
    port=$((8080 + i))  # Tạo port bắt đầu từ 8080

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    username="user$i"
    password=$(openssl rand -base64 12)

    # Thêm tên người dùng và mật khẩu vào file xác thực
    htpasswd -b $htpasswd_file $username $password

    # Khởi động proxy trên cổng cho mỗi địa chỉ IPv6
    socat TCP4-LISTEN:$port,fork TCP6:"$ipv6":80 &
    echo "Proxy đang chạy trên $ipv4_address:$port chuyển tiếp đến $ipv6:80 với tên người dùng $username và mật khẩu $password"
done

# Khởi động Apache để xử lý xác thực
sudo systemctl start httpd
sudo systemctl enable httpd

# Đợi các proxy chạy
wait
