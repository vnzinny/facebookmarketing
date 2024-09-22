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

# Tạo các proxy cho IPv6
for ((i=0; i<100; i++)); do
    ipv6="${ipv6_addresses[i]}"
    port=$((8080 + i))  # Tạo port bắt đầu từ 8080

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    username="user$i"
    password=$(openssl rand -base64 12)

    # Thêm tên người dùng và mật khẩu vào file xác thực
    htpasswd -b $htpasswd_file $username $password

    # Thêm cấu hình cho từng cổng
    echo "http_port $ipv4_address:$port" >> $squid_conf  # Sử dụng địa chỉ IPv4 cho thông tin đăng nhập

    # Tạo ACL cho cổng cụ thể
    echo "acl port$i myportname $port" >> $squid_conf
    
    # Áp dụng địa chỉ IPv6 cho ACL của cổng
    echo "tcp_outgoing_address $ipv6 port$i" >> $squid_conf  # Sử dụng IPv6 cho việc chuyển tiếp

    # Thêm quy tắc để chỉ cho phép sử dụng IPv6
    echo "http_access deny all" >> $squid_conf
    echo "http_access allow port$i" >> $squid_conf  # Cho phép truy cập cho cổng cụ thể

    # Thêm thông tin proxy vào danh sách
    proxy_list+=("$ipv4_address:$port:$username:$password")

    echo "Proxy đang chạy trên $ipv4_address:$port với tên người dùng $username và mật khẩu $password, chuyển tiếp đến $ipv6"
done

# Tạo proxy sử dụng chỉ IPv4 trên cổng 8180
port=8180
username="user_ipv4"
password=$(openssl rand -base64 12)

# Thêm tên người dùng và mật khẩu vào file xác thực
htpasswd -b $htpasswd_file $username $password

# Thêm cấu hình cho cổng 8180
echo "http_port $ipv4_address:$port" >> $squid_conf  # Sử dụng địa chỉ IPv4 cho thông tin đăng nhập

# Tạo ACL cho cổng 8180
echo "acl port_ipv4 myportname $port" >> $squid_conf

# Áp dụng địa chỉ IPv4 cho ACL của cổng
echo "tcp_outgoing_address $ipv4_address port_ipv4" >> $squid_conf  # Sử dụng IPv4 cho việc chuyển tiếp

# Quy tắc cho phép sử dụng IPv4
echo "http_access allow port_ipv4" >> $squid_conf  # Cho phép truy cập cho cổng 8180

# Thêm thông tin proxy vào danh sách
proxy_list+=("$ipv4_address:$port:$username:$password")

echo "Proxy đang chạy trên $ipv4_address:$port với tên người dùng $username và mật khẩu $password, sử dụng IPv4 cho kết nối ra ngoài"

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
