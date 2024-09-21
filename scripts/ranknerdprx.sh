#!/bin/bash

# Cài đặt các gói cần thiết
echo "Cài đặt các gói cần thiết..."
yum -y install wget gcc net-tools bsdtar zip make nano tar >/dev/null

# Cài đặt 3proxy
install_3proxy() {
    echo "Cài đặt 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | tar -zxvf-
    cd 3proxy-0.9.4
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/3proxy
    cd ..
}

# Hàm tạo file cấu hình 3proxy
gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.8.8
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth strong

users $1:CL:$2

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $3 " -i" $4 " -e"$5"\n" \
"flush\n"}' ${WORKDIR}/data.txt)
EOF
}

# Nhập 100 IPv6 từ người dùng
read_ipv6() {
    echo "Nhập 100 địa chỉ IPv6 (mỗi dòng một địa chỉ):"
    > ${WORKDIR}/ipv6_list.txt
    for i in $(seq 1 100); do
        read -p "IPv6 address $i: " ipv6
        echo $ipv6 >> ${WORKDIR}/ipv6_list.txt
    done
}

# Tạo file dữ liệu proxy
gen_data() {
    echo "Tạo file dữ liệu proxy..."
    USERNAME=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
    PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
    PORT=21000
    while IFS= read -r ipv6; do
        echo "$USERNAME/$PASSWORD/localhost/$PORT/$ipv6" >> ${WORKDIR}/data.txt
        PORT=$((PORT + 1))
    done < ${WORKDIR}/ipv6_list.txt
}

# Cấu hình iptables để mở port
gen_iptables() {
    echo "Cấu hình iptables..."
    while IFS= read -r line; do
        PORT=$(echo $line | cut -d "/" -f 4)
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    done < ${WORKDIR}/data.txt
}

# Thêm IPv6 vào giao diện mạng
gen_ifconfig() {
    echo "Thêm địa chỉ IPv6 vào giao diện mạng..."
    while IFS= read -r line; do
        IPV6=$(echo $line | cut -d "/" -f 5)
        ip -6 addr add $IPV6/64 dev eth0
    done < ${WORKDIR}/data.txt
}

# Tạo file cấu hình 3proxy
gen_3proxy_config() {
    echo "Tạo file cấu hình 3proxy..."
    USERNAME=$(awk -F "/" '{print $1}' ${WORKDIR}/data.txt | head -1)
    PASSWORD=$(awk -F "/" '{print $2}' ${WORKDIR}/data.txt | head -1)
    gen_3proxy $USERNAME $PASSWORD > /usr/local/etc/3proxy/3proxy.cfg
}

# Cấu hình chạy khi khởi động
config_rc_local() {
    echo "Cấu hình chạy khi khởi động..."
    cat <<EOF > /etc/rc.d/rc.local
#!/bin/bash
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 1000048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
    chmod +x /etc/rc.d/rc.local
}

# Tạo các file khởi động iptables và ifconfig
create_boot_scripts() {
    echo "Tạo các file khởi động iptables và ifconfig..."
    gen_iptables > ${WORKDIR}/boot_iptables.sh
    gen_ifconfig > ${WORKDIR}/boot_ifconfig.sh
    chmod +x ${WORKDIR}/boot_*.sh
}

# Bắt đầu cài đặt
main() {
    echo "Bắt đầu cài đặt..."
    WORKDIR="/home/cloudfly"
    mkdir -p $WORKDIR

    install_3proxy
    read_ipv6
    gen_data
    create_boot_scripts
    gen_3proxy_config
    config_rc_local

    # Thực thi script khởi động
    bash /etc/rc.d/rc.local

    echo "Hoàn tất cài đặt proxy. Proxy đã sẵn sàng!"
}

main
