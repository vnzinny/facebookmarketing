#!/bin/bash

# Lấy địa chỉ IPv4 của VPS
ipv4_address=$(hostname -I | awk '{print $1}')

# Lấy tất cả địa chỉ IPv6 từ VPS
echo "Đang lấy tất cả địa chỉ IPv6..."
ipv6_addresses=($(ip -6 addr show | grep 'inet6' | awk '{print $2}' | cut -d'/' -f1))

# Kiểm tra xem có đủ địa chỉ IPv6 không
num_ipv6=${#ipv6_addresses[@]}
if [ $num_ipv6 -lt 1 ]; then
    echo "Không có địa chỉ IPv6 nào được tìm thấy trên VPS. Vui lòng kiểm tra lại."
    exit 1
fi

# Hiển thị các địa chỉ IPv6 đã lấy
echo "Danh sách địa chỉ IPv6 đã lấy:"
for ipv6 in "${ipv6_addresses[@]}"; do
    echo "$ipv6"
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

# Tạo các proxy cho từng địa chỉ IPv6
for ((i=0; i<num_ipv6; i++)); do
    ipv6="${ipv6_addresses[i]}"
    port=$((8080 + i))  # Tạo port bắt đầu từ 8080

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    username="user$i"
    password=$(openssl rand -base64 12)

    # Thêm tên người dùng và mật khẩu vào file xác thực
    htpasswd -b $htpasswd_file $username $password

    # Thêm cấu hình cho từng cổng và địa chỉ IPv6
    echo "http_port $port" >> $squid_conf
    
    # Tạo ACL cho cổng cụ thể
    echo "acl port$i myportname $port" >> $squid_conf
    
    # Áp dụng địa chỉ IPv6 cho ACL của cổng
    echo "tcp_outgoing_address $ipv6 port$i" >> $squid_conf

    # Thêm thông tin proxy vào danh sách
    proxy_list+=("$ipv4_address:$port:$username:$password")

    echo "Proxy đang chạy trên $ipv4_address:$port với tên người dùng $username và mật khẩu $password, chuyển tiếp đến $ipv6"
done

# Khởi động Squid
sudo systemctl restart squid
sudo systemctl enable squid

# Xuất danh sách proxy
echo -e "\nDanh sách proxy đã tạo:"
for proxy in "${proxy_list[@]}"; do
    echo "$proxy"
done

# Đợi Squid chạy
wait
