#!/bin/bash

# Cài đặt các gói cần thiết trên AlmaLinux 8
yum install -y dante-server

# File cấu hình dante
config_file="/etc/sockd.conf"

# Tạo file cấu hình Dante với các chỉnh sửa
cat <<EOL > $config_file
logoutput: /var/log/sockd.log

internal: eth0 port = 1080
external: eth0

# Quy tắc client - từ khóa "socks pass" thay cho "pass"
client socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# Quy tắc server - từ khóa "socks pass" thay cho "pass"
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# Quyền user cho dante
user.privileged: root
user.unprivileged: nobody

# Đặt quyền cho các file được tạo
user.libwrap: nobody
EOL

echo "Cấu hình Dante đã được tạo tại $config_file"

# Tự động lấy các địa chỉ IPv6 trên VPS
ipv6_list=$(ip -6 addr show scope global | awk '/inet6/{print $2}' | cut -d/ -f1)
ipv4_address=$(curl -s ipv4.icanhazip.com)

# Nếu không lấy được danh sách IPv6
if [ -z "$ipv6_list" ]; then
    echo "Không tìm thấy địa chỉ IPv6 hợp lệ trên VPS."
    exit 1
fi

# Hiển thị các địa chỉ IPv6 đã lấy
echo "Danh sách IPv6 đã tìm thấy:"
echo "$ipv6_list"

# Tạo proxy từ các địa chỉ IPv6 lấy được
port_start=10000
output_file="proxy_list.txt"
> $output_file

index=1
for ipv6 in $ipv6_list; do
    port=$((port_start + index))
    user="user$index"
    pass="pass$index"
    
    # Cập nhật vào file cấu hình sockd.conf
    echo "socks pass {" >> $config_file
    echo "    from: $ipv6 to: 0.0.0.0/0" >> $config_file
    echo "    log: connect disconnect" >> $config_file
    echo "}" >> $config_file
    
    # Ghi proxy vào file output
    echo "$ipv4_address:$port:$user:$pass" >> $output_file
    
    index=$((index + 1))
done

echo "Danh sách proxy đã tạo:"
cat $output_file

# Khởi động lại dịch vụ sockd
systemctl restart sockd

# Kiểm tra trạng thái dịch vụ sockd
systemctl status sockd

# Nếu có lỗi, kiểm tra log
if [ $? -ne 0 ]; then
    echo "Dịch vụ sockd gặp lỗi, kiểm tra log tại /var/log/sockd.log"
fi
