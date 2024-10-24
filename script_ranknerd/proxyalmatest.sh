#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c12
    echo
}

# Lọc và lấy địa chỉ IPv6 hợp lệ
get_ipv6() {
    ip -6 addr show | grep "inet6" | grep -v "scope link" | awk '{print $2}' | grep -v '^::1/' | cut -d'/' -f1
}

# Lọc và lấy địa chỉ IPv4 hợp lệ
get_ipv4() {
    ip -4 addr show | grep "inet" | awk '{print $2}' | cut -d'/' -f1 | grep -v '^127\.'
}

install_3proxy() {
	echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/0.9.3.tar.gz"
    wget -qO- $URL | tar -zxvf-
    cd 3proxy-0.9.3
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
	cd $WORKDIR
}

download_proxy() {
    cd /home/duyscript
    curl -F "file=@proxy.txt" https://file.io
}


gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 3 10 30 60 180 1800 15 60
setgid 60000
setuid 60000
stacksize 6291456
log /usr/local/etc/3proxy/logs/3proxy.log
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 ", "}' ${WORKDATA})

# Thêm phần cấu hình cho IPv6 và IPv4 chỉ khi có đủ thông tin
$(awk -F "/" '
{
    if ($5 != "" && $6 == "ipv6") {  # Nếu có IPv6, cấu hình proxy cho IPv6
        print "auth strong\n" \
        "allow " $1 "\n" \
        "proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
        "flush\n"
    } else if ($3 != "") {  # Nếu không có IPv6 nhưng có IPv4, cấu hình proxy cho IPv4
        print "auth strong\n" \
        "allow " $1 "\n" \
        "proxy -n -a -p" $4 " -i" $3 "\n" \
        "flush\n"
    }
}' ${WORKDATA})

EOF
}


gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}


gen_data() {
    # Lấy tất cả địa chỉ IPv6 hợp lệ
    IPV6_LIST=$(get_ipv6)
    readarray -t ipv6_array <<< "$IPV6_LIST"

    # Lấy tất cả địa chỉ IPv4 hợp lệ
    IPV4_LIST=$(get_ipv4)
    readarray -t ipv4_array <<< "$IPV4_LIST"

    # Tạo dữ liệu cho IPv6
    for ((i = 0; i < ${#ipv6_array[@]}; i++)); do
        port_ipv6=$(($FIRST_PORT + $i))
        if [ $port_ipv6 -le $LAST_PORT ]; then
            echo "user$port_ipv6/$(random)/$IP4/$port_ipv6/${ipv6_array[$i]}/ipv6"
        fi
    done

    # Tạo dữ liệu cho IPv4
    for ((j = 0; j < ${#ipv4_array[@]}; j++)); do
        port_ipv4=$(($LAST_PORT + 1 + $j))
        if [ $port_ipv4 -le $LAST_PORT_IPV4 ]; then
            echo "user$port_ipv4/$(random)/$IP4/$port_ipv4/${ipv4_array[$j]}/ipv4"
        fi
    done
}


gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}


gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '
{
    # Kiểm tra địa chỉ IPv6 và IPv4
    if ($5 != "" && $6 == "ipv6" && system("ip -6 addr show dev eth0 | grep -q " $5) != 0) {
        print "ifconfig eth0 inet6 add " $5 "/64"
    }
    if ($3 != "" && $6 == "ipv4" && system("ip addr show dev eth0 | grep -q " $3) != 0) {
        print "ifconfig eth0 inet add " $3 " netmask 255.255.255.0"
    }
}' ${WORKDATA})
EOF
}


echo "Installing required packages..."
dnf -y install nano wget gcc net-tools tar zip iptables iptables-services make bind-utils >/dev/null

# Cấu hình sysctl
configure_sysctl() {
    echo "Configuring sysctl..."
    
    # Xóa nội dung cũ trong /etc/sysctl.conf
    if [ -f /etc/sysctl.conf ]; then
        echo "Xóa cấu hình cũ trong /etc/sysctl.conf..."
        > /etc/sysctl.conf
    fi

    # Thêm cấu hình mới
    echo "* hard nofile 999999" >> /etc/security/limits.conf
    echo "* soft nofile 999999" >> /etc/security/limits.conf
    echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6=0" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6=0" >> /etc/sysctl.conf
    echo "net.ipv6.conf.lo.disable_ipv6=0" >> /etc/sysctl.conf

    # Áp dụng các thay đổi sysctl
    sysctl -p
	systemctl restart network
}

# Tạo file dịch vụ cho 3proxy
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy tiny proxy server
Documentation=man:3proxy(1)
After=network.target

[Service]
ExecStart=/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -SIGUSR1 $MAINPID
KillMode=process
Restart=on-failure
RestartSec=60s
LimitNOFILE=65535
LimitNPROC=1024

[Install]
WantedBy=multi-user.target
EOF

# Kích hoạt dịch vụ 3proxy
systemctl daemon-reload
systemctl enable 3proxy.service
systemctl start 3proxy.service

# Bật iptables
systemctl enable iptables
systemctl start iptables

# Tắt firewalld
systemctl stop firewalld
systemctl disable firewalld

# Create and enable rc.local unit file for AlmaLinux 8
cat <<EOF > /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.d/rc.local Compatibility
ConditionPathExists=/etc/rc.d/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.d/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF

# Ensure /etc/rc.d/rc.local exists and is executable
if [ ! -f /etc/rc.d/rc.local ]; then
    touch /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
    echo "#!/bin/bash" > /etc/rc.d/rc.local
fi

# Bật rc.local service
chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Cài đặt 3proxy
install_3proxy

# Cấu hình sysctl
configure_sysctl

WORKDIR="/home/duyscript"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

IP4=$(curl -4 -s icanhazip.com)

# Lấy danh sách địa chỉ IPv6
IPV6_LIST=$(get_ipv6)

if [ -z "$IPV6_LIST" ]; then
    echo "No valid IPv6 addresses found."
    exit 1
fi

echo "Internal IP4: ${IP4}, External IPv6 list: ${IPV6_LIST}"

# Tính số lượng địa chỉ IPv6
IPV6_COUNT=$(echo "$IPV6_LIST" | wc -l)

while :; do
    read -p "Enter FIRST_PORT between 21000 and 61000: " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 21000 && FIRST_PORT <= 61000)); then
        echo "Valid number!"
        break;
    else
        echo "Number out of range, try again."
    fi
done

# Cập nhật LAST_PORT dựa trên số lượng địa chỉ IPv6
LAST_PORT=$(($FIRST_PORT + IPV6_COUNT - 1))

# Đặt cổng cho IPv4 bắt đầu ngay sau cổng cuối của IPv6
FIRST_PORT_IPV4=$(($LAST_PORT + 1))
# Cập nhật LAST_PORT_IPV4 dựa trên số lượng địa chỉ IPv4
LAST_PORT_IPV4=$(($FIRST_PORT_IPV4 + $(get_ipv4 | wc -l) - 1))

echo "LAST_PORT is $LAST_PORT. FIRST_PORT_IPV4 is $FIRST_PORT_IPV4. Continue..."

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.d/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.d/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod 0755 /etc/rc.d/rc.local
bash /etc/rc.d/rc.local

gen_proxy_file_for_user

echo "Starting Proxy..."
download_proxy