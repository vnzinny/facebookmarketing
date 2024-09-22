#!/bin/bash

# Cập nhật hệ thống và cài đặt các gói cần thiết
dnf update -y
dnf install -y dante-server firewalld

# Bật và khởi động firewalld nếu chưa chạy
systemctl enable firewalld
systemctl start firewalld

# Lấy địa chỉ IPv4 của VPS
ipv4=$(hostname -I | awk '{print $1}')
echo "Địa chỉ IPv4 của VPS: $ipv4"

# Lấy danh sách IPv6 có sẵn
ipv6_list=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d '/' -f1)

# Kiểm tra và in danh sách IPv6
echo "Danh sách IPv6 hợp lệ đã tìm thấy:"
ipv6_count=0
for ipv6 in $ipv6_list; do
    echo "$ipv6"
    ((ipv6_count++))
done

echo "Tổng số IPv6 hợp lệ: $ipv6_count"

# Tạo file cấu hình sockd
cat <<EOT > /etc/sockd.conf
logoutput: /var/log/sockd.log

# Địa chỉ cho SOCKS Proxy
internal: eth0 port = 1080
external: eth0

# Quy tắc truy cập
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

# Quy tắc cho phép
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
EOT

# Tạo file dịch vụ systemd cho sockd
cat <<EOT > /etc/systemd/system/sockd.service
[Unit]
Description=Dante SOCKS Proxy Server
After=network.target

[Service]
ExecStart=/usr/sbin/sockd -f /etc/sockd.conf
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=/var/run/sockd.pid

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd để nhận file dịch vụ mới
systemctl daemon-reload

# Mở port 1080 trong firewall
firewall-cmd --add-port=1080/tcp --permanent
firewall-cmd --reload

# Bật và khởi động dịch vụ sockd
systemctl enable sockd
systemctl start sockd

# Tạo proxy với thông tin đăng nhập ngẫu nhiên và xuất ra file
output_file="proxy_list.txt"
port_start=10000

echo "Tạo danh sách proxy với thông tin đăng nhập ngẫu nhiên..."

> $output_file
for ipv6 in $ipv6_list; do
    user=$(openssl rand -hex 4)
    pass=$(openssl rand -hex 4)
    port=$((port_start++))
    
    echo "$ipv4:$port:$user:$pass" >> $output_file
    echo "user.privileged: $user" >> /etc/sockd.conf
    echo "password: $pass" >> /etc/sockd.conf
    echo "client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 log: connect disconnect }" >> /etc/sockd.conf
    echo "socks pass { from: $ipv6 to: 0.0.0.0/0 log: connect disconnect }" >> /etc/sockd.conf
done

echo "Danh sách proxy đã tạo:"
cat $output_file

# Kiểm tra trạng thái dịch vụ
systemctl status sockd

echo "Cấu hình và tạo proxy hoàn thành!"
