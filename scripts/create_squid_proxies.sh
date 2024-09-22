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
echo "http_port 3128" > $squid_conf  # Cấu hình cổng mặc định
echo "auth_param basic program /usr/lib64/squid/basic_ncsa_auth $htpasswd_file" >> $squid_conf
echo "auth_param basic realm Proxy" >> $squid_conf
echo "acl authenticated proxy_auth REQUIRED" >> $squid_conf
echo "http_access allow authenticated" >> $squid_conf
echo "http_access deny all" >> $squid_conf

# Khởi tạo danh sách proxy
proxy_list=()

# Cấu hình IPv6 cho cổng 8080 đến 8179
for ((i=0; i<100; i++)); do
    ipv6="${ipv6_addresses[i]}"
    port=$((8080 + i))  # Tạo port bắt đầu từ 8080

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    username="user$i"
    password=$(openssl rand -base64 12)

    # Thêm tên người dùng và mật khẩu vào file xác thực
    htpasswd -b $htpasswd_file $username $password

    # Thêm cấu hình cho từng cổng và địa chỉ IPv6
    echo "http_port [$ipv6]:$port" >> $squid_conf
    
    # Tạo ACL cho cổng cụ thể
    echo "acl port$i myportname $port" >> $squid_conf
    
    # Áp dụng địa chỉ IPv6 cho ACL của cổng
    echo "tcp_outgoing_address $ipv6 port$i" >> $squid_conf

    # Ngăn không cho cổng sử dụng IPv4
    echo "tcp_outgoing_address none port$i" >> $squid_conf

    # Thêm thông tin proxy vào danh sách
    proxy_list+=("[$ipv6]:$port:$username:$password")

    echo "Proxy đang chạy trên [$ipv6]:$port với tên người dùng $username và mật khẩu $password."
done

# Cấu hình chỉ IPv4 cho cổng 8180
port_ipv4=8180
username="user_ipv4"
password=$(openssl rand -base64 12)

# Thêm tên người dùng và mật khẩu vào file xác thực
htpasswd -b $htpasswd_file $username $password

# Cấu hình cổng 8180 cho IPv4
echo "http_port $ipv4_address:$port_ipv4" >> $squid_conf
echo "acl port_ipv4 myportname $port_ipv4" >> $squid_conf
echo "tcp_outgoing_address $ipv4_address port_ipv4" >> $squid_conf

# Thêm thông tin proxy IPv4 vào danh sách
proxy_list+=("$ipv4_address:$port_ipv4:$username:$password")

echo "Proxy đang chạy trên $ipv4_address:$port_ipv4 với tên người dùng $username và mật khẩu $password chỉ sử dụng IPv4."

# Khởi động lại Squid
sudo systemctl restart squid
sudo systemctl enable squid

# Xuất danh sách proxy
echo -e "\nDanh sách proxy đã tạo:"
for proxy in "${proxy_list[@]}"; do
    echo "$proxy"
done
