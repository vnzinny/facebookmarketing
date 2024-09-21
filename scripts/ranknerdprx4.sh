#!/bin/bash

# Cài đặt các gói cần thiết
echo "Cài đặt các gói cần thiết..."
yum -y install wget gcc net-tools bsdtar zip make nano tar >/dev/null

# Cài đặt 3proxy
install_3proxy() {
    echo "Cài đặt 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.3.tar.gz"
    wget -qO- $URL | tar -zxvf-
    
    # Kiểm tra thư mục sau khi giải nén
    cd 3proxy-0.9.3 || { echo "Thư mục 3proxy không tồn tại!"; exit 1; }
    
    # Biên dịch 3proxy
    make -f Makefile.Linux || { echo "Lỗi khi biên dịch 3proxy!"; exit 1; }

    # Tạo thư mục nếu chưa có
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}

    # Kiểm tra file đã biên dịch
    if [ ! -f src/3proxy ]; then
        echo "File 3proxy không được tạo ra sau khi biên dịch!"
        exit 1
    fi

    # Sao chép file 3proxy vào thư mục bin
    cp src/3proxy /usr/local/etc/3proxy/bin/3proxy || { echo "Không thể sao chép file 3proxy!"; exit 1; }

    # Trở về thư mục làm việc ban đầu
    cd .. || exit 1
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
    echo "Tạ
