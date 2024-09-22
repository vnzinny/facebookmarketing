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

# Tạo file xác thực cho Squid
htpasswd_file="/etc/squid/squid_passwd"
touch $htpasswd_file

# Cấu hình Squid
squid_conf="/etc/squid/squid.conf"
cp $squid_conf $squid_conf.bak  # Sao lưu cấu hình hiện tại
echo "http_port $ipv4_address:3128" > $squid_conf  # Cấu hình cổng mặc định với IPv4
echo "auth_param basic program /usr/lib64/squid/basic_ncsa_auth $htpasswd_file" >> $squid_conf
echo "auth_param basic realm Proxy" >> $squid_conf
echo "acl authenticated proxy_auth REQUIRED" >> $squid_conf
echo "http_access allow authenticated" >> $squid_conf
echo "http_access deny all" >> $squid_conf

# Khởi tạo danh sách proxy
proxy_list=()

# Tạo các proxy
for ((i=0; i<100; i++)); do
    ipv6="${ipv6_addresses[i]}"
    port=$((8080 + i))  # Tạo port bắt đầu từ 8080

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    username="user$i"
    password=$(openssl rand -base64 12)

    # Thêm tên người dùng và mật khẩu vào file xác thực
    htpasswd -b $htpasswd_file $username $password

    # Cấu hình cho từng port và IPv6
    if (( port <= 8179 )); then
        echo "http_port $ipv4_address:$port" >> $squid_conf
        echo "tcp_outgoing_address $ipv6 $port" >> $squid_conf  # Sử dụng IPv6 cho các cổng 8080-8179
    elif (( port == 8180 )); then
        echo "http_port $ipv4_address:$port" >> $squid_conf
        echo "tcp_outgoing_address $ipv4_address $port" >> $squid_conf  # Sử dụng IPv4 cho cổng 8180
    fi

    # Thêm thông tin proxy vào danh sách
    proxy_list+=("$ipv4_address:$port:$username:$password")

    echo "Proxy đang chạy trên $ipv4_address:$port với tên người dùng $username và mật khẩu $password, sử dụng $ipv6 cho kết nối ra ngoài"
done

# Khởi động Squid
sudo systemctl restart squid
sudo systemctl enable squid

# Xuất danh sách proxy
echo -e "\nDanh sách proxy đã tạo:"
for proxy in "${proxy_list[@]}"; do
    echo "$proxy"
done
