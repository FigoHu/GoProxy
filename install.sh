#!/bin/sh
function pre_install(){
    yum update
    yum install -y wget curl vim git
    yum install -y autoconf automake libtool
    yum install -y epel-release
    yum install -y jq
}

function go_install(){
    wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.13.5.linux-amd64.tar.gz
    
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
    source ~/.bashrc
}


function firewall(){
    firewall-cmd --permanent --add-port=8888/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --reload
}

function acme_install(){
    curl  https://get.acme.sh | sh
}

function install(){
    pre_install
    go_install
    add_firewall
    acme_install
	
}

install