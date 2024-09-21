#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c12
	echo
}
# Hàm tạo file và ghi danh sách IPv6
create_ipv6_file() {
  # Tạo file nếu chưa tồn tại
  fixed_ipv6_file="fixed_ipv6.txt"
  if [ ! -f "$fixed_ipv6_file" ]; then
    touch "$fixed_ipv6_file"
    echo "File $fixed_ipv6_file đã được tạo."
  fi

  # Ghi danh sách IPv6 vào file
  echo "Nhập các địa chỉ IPv6, mỗi địa chỉ trên một dòng. Nhập 'quit' để kết thúc."
  while IFS= read -r ipv6; do
    if [[ "$ipv6" == "quit" ]]; then
      break
    fi
    echo "$ipv6" >> $fixed_ipv6_file
  done
}
install_3proxy() {
    echo "installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    #cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    #chmod +x /etc/init.d/3proxy
    #chkconfig 3proxy on
    cd $WORKDIR
}
download_proxy() {
cd /home/cloudfly
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
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

gen_data() {
    while IFS= read -r ipv6; do
        port=$((10000 + $LINENO))  # Giữ nguyên cách tính port như ban đầu
        echo "user$port/$(random)/$IP4/$port/$ipv6"
    done < "$fixed_ipv6.txt"
    # Lưu ý dấu "<" ở cuối dòng để đọc dữ liệu từ file
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}
echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_
# Gọi hàm để thực hiện
create_ipv6_file

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

while :; do
  read -p "Enter FIRST_PORT between 10000 and 20000: " FIRST_PORT
  [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 20000)); then
    echo "OK! Valid number"
    break
  else
    echo "Number out of range, try again"
  fi
done
LAST_PORT=$(($FIRST_PORT + 100))
echo "LAST_PORT is $LAST_PORT. Continue..."

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 1000048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
chmod 0755 /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user

echo "Starting Proxy"
download_proxy
