#!/bin/bash

# Đường dẫn chứa file quy tắc iptables của script tạo proxy
IPTABLES_FILE="/home/duyscript/boot_iptables.sh"

# Lấy địa chỉ IP từ DDNS của No-IP
IP=$(dig +short vnzinny.ddns.net)
if [[ -z "$IP" ]]; then
    echo "Failed to get IP from DDNS."
    exit 1
fi

# Các cổng cần mở
PROXY_PORTS=($(seq 21000 21100))
ALLOWED_PROTOCOLS=("tcp" "udp")  # Giao thức cần thiết

# Kiểm tra các gói đã cài đặt và cài nếu thiếu
install_required_packages() {
    echo "Checking and installing required packages..."
    packages=("iptables" "bind-utils")
    for pkg in "${packages[@]}"; do
        if ! rpm -q $pkg >/dev/null 2>&1; then
            echo "Installing $pkg..."
            dnf -y install $pkg >/dev/null
        else
            echo "$pkg is already installed."
        fi
    done
}

# Xóa các quy tắc cũ không cần thiết
remove_old_rules() {
    echo "Clearing all current iptables rules..."
    iptables -F  # Xóa tất cả các quy tắc
    > $IPTABLES_FILE  # Xóa nội dung file
    echo "All iptables rules cleared."
}

# Mở các cổng cho kết nối proxy từ địa chỉ IP dân cư
allow_proxy_ports() {
    echo "Allowing proxy ports from your residential IP ($IP)..."
    
    # Kiểm tra và xóa các quy tắc mở cổng cũ
    remove_old_rules

    for protocol in "${ALLOWED_PROTOCOLS[@]}"; do
        for port in "${PROXY_PORTS[@]}"; do
            if ! iptables -C INPUT -p $protocol --dport $port -s $IP -j ACCEPT 2>/dev/null; then
                iptables -I INPUT -p $protocol --dport $port -s $IP -j ACCEPT
                echo "iptables -I INPUT -p $protocol --dport $port -s $IP -j ACCEPT" >> $IPTABLES_FILE
                echo "Allowed port $port for $IP"
            fi
        done
    done

    # Mở cổng SSH cho IP của bạn
    iptables -I INPUT -p tcp --dport 22 -s $IP -j ACCEPT
    echo "iptables -I INPUT -p tcp --dport 22 -s $IP -j ACCEPT" >> $IPTABLES_FILE

    # Mở cổng HTTP/HTTPS cho mọi người
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    echo "iptables -I INPUT -p tcp --dport 80 -j ACCEPT" >> $IPTABLES_FILE
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    echo "iptables -I INPUT -p tcp --dport 443 -j ACCEPT" >> $IPTABLES_FILE
}

# Chặn các dịch vụ và cổng không cần thiết
block_unnecessary_services() {
    echo "Blocking unnecessary services and ports..."

    # Chặn tất cả các dịch vụ ngoại trừ những cổng đã được cho phép
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    # Cho phép các kết nối liên quan và đã được thiết lập
    if ! iptables -C INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        echo "iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT" >> $IPTABLES_FILE
    fi

    # Cho phép loopback (localhost)
    if ! iptables -C INPUT -i lo -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -i lo -j ACCEPT
        echo "iptables -A INPUT -i lo -j ACCEPT" >> $IPTABLES_FILE
    fi

    # Chặn các cổng không cần thiết
    iptables -A INPUT -p tcp --dport 25 -j DROP  # Chặn SMTP
    echo "iptables -A INPUT -p tcp --dport 25 -j DROP" >> $IPTABLES_FILE
    iptables -A INPUT -p tcp --dport 3306 -j DROP # Chặn MySQL
    echo "iptables -A INPUT -p tcp --dport 3306 -j DROP" >> $IPTABLES_FILE
    iptables -A INPUT -p tcp --dport 21 -j DROP  # Chặn FTP
    echo "iptables -A INPUT -p tcp --dport 21 -j DROP" >> $IPTABLES_FILE
    iptables -A INPUT -p tcp --dport 3389 -j DROP # Chặn RDP
    echo "iptables -A INPUT -p tcp --dport 3389 -j DROP" >> $IPTABLES_FILE
}

# Kiểm tra xem các quy tắc đã được tạo đúng
check_rules() {
    echo "Checking iptables rules..."
    for port in "${PROXY_PORTS[@]}"; do
        if iptables -C INPUT -p tcp --dport $port -s $IP -j ACCEPT 2>/dev/null; then
            echo "Rule for port $port from IP $IP is correctly set."
        else
            echo "Rule for port $port from IP $IP is NOT set."
        fi
    done

    # Kiểm tra các quy tắc SSH, HTTP, HTTPS
    for service in 22 80 443; do
        if iptables -C INPUT -p tcp --dport $service -s $IP -j ACCEPT 2>/dev/null; then
            echo "Rule for service on port $service from IP $IP is correctly set."
        else
            echo "Rule for service on port $service from IP $IP is NOT set."
        fi
    done

    # Kiểm tra các quy tắc chặn
    for blocked_port in 25 3306 21 3389; do
        if iptables -C INPUT -p tcp --dport $blocked_port -j DROP 2>/dev/null; then
            echo "Blocking rule for port $blocked_port is correctly set."
        else
            echo "Blocking rule for port $blocked_port is NOT set."
        fi
    done
}

# Cài đặt cron để chạy script này mỗi giờ một lần
install_cronjob() {
    echo "Setting up cron job to run this script every hour..."
    
    # Đường dẫn đến script
    CRON_JOB="/home/duyscript/firewall.sh"

    # Kiểm tra xem cron job đã tồn tại chưa
    if crontab -l | grep -q "$CRON_JOB"; then
        echo "Cron job already exists. Skipping..."
    else
        # Nếu chưa tồn tại, thêm công việc cron
        (crontab -l | grep -v "$CRON_JOB"; echo "0 * * * * $CRON_JOB") | crontab -
        echo "Cron job added."
    fi
}

# Gọi các hàm
install_required_packages
allow_proxy_ports
block_unnecessary_services
check_rules
install_cronjob
chmod +x /home/duyscript/boot_iptables.sh && bash /home/duyscript/boot_iptables.sh
iptables-save > /etc/sysconfig/iptables
iptables -L -n -v
service iptables save

echo "Script executed successfully."
