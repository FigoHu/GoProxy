#!/bin/sh
function pre_install(){
    yum -y update
    yum install -y wget curl vim git
    yum install -y autoconf automake libtool
    yum install -y epel-release
    yum install -y jq
    yum install -y crontabs
    
    mkdir /root/golang/
    cd /root/golang/
    mkdir /data
}

function go_install(){
    cd /root/
    wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
    tar -C /usr/local -zxvf go1.13.5.linux-amd64.tar.gz
	
    echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin'  >> ~/.bashrc
    echo 'export GOPATH=/root/golang' >> ~/.bashrc
    
    . ~/.bashrc
    
    rm -rf go1.13.5.linux-amd64.tar.gz
    
    go get github.com/spf13/viper
    go get github.com/fsnotify/fsnotify
    
    cd /root/golang
    go build httpServer.go
    go build httpProxy.go
}


#function add_firewall(){
    #firewall-cmd --permanent --add-port=8888/tcp
    #firewall-cmd --permanent --add-port=80/tcp
    #firewall-cmd --reload
#}

function acme_install(){
    curl  https://get.acme.sh | sh
}

function add_httpServer(){
cat <<'EOF' > /root/golang/httpServer.go
// +build ignore
package main

import (
    "net/http"
    "fmt"
    "os"
    "github.com/spf13/viper"
    "log"
)

func main() {
    viper.SetConfigName("config")
    viper.AddConfigPath("./data/")
    viper.SetConfigType("json")
    err := viper.ReadInConfig()
    if err != nil {
        fmt.Printf("config file error: %s\n", err)
        os.Exit(1)
    }
    var wwwdir string
    var http_port string
    wwwdir,_ = viper.Get("www_dir").(string)
    http_port,_ = viper.Get("http_port").(string)
    http.Handle("/", http.FileServer(http.Dir(wwwdir)))
    err = http.ListenAndServe(":"+http_port, nil)
    if err != nil {
        log.Fatal("ListenAndServe: ", err)
    }
}
EOF
}

function add_httpProxy(){
cat <<'EOF' > /root/golang/httpProxy.go
// +build ignore
package main
import (
    "crypto/tls"
    "flag"
    "io"
    "log"
    "net"
    "net/http"
    "time"
    "fmt"
    "os"
    "github.com/spf13/viper"
)
func handleTunneling(w http.ResponseWriter, r *http.Request) {
    dest_conn, err := net.DialTimeout("tcp", r.Host, 10*time.Second)
    if err != nil {
        http.Error(w, err.Error(), http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
    hijacker, ok := w.(http.Hijacker)
    if !ok {
        http.Error(w, "Hijacking not supported", http.StatusInternalServerError)
        return
    }
    client_conn, _, err := hijacker.Hijack()
    if err != nil {
        http.Error(w, err.Error(), http.StatusServiceUnavailable)
    }
    go transfer(dest_conn, client_conn)
    go transfer(client_conn, dest_conn)
}
func transfer(destination io.WriteCloser, source io.ReadCloser) {
    defer destination.Close()
    defer source.Close()
    io.Copy(destination, source)
}
func handleHTTP(w http.ResponseWriter, req *http.Request) {
    resp, err := http.DefaultTransport.RoundTrip(req)
    if err != nil {
        http.Error(w, err.Error(), http.StatusServiceUnavailable)
        return
    }
    defer resp.Body.Close()
    copyHeader(w.Header(), resp.Header)
    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)
}
func copyHeader(dst, src http.Header) {
    for k, vv := range src {
        for _, v := range vv {
            dst.Add(k, v)
        }
    }
}
func main() {
    viper.SetConfigName("config")
    viper.AddConfigPath("./data/")
    viper.SetConfigType("json")
    err := viper.ReadInConfig()
    if err != nil {
        fmt.Printf("config file error: %s\n", err)
        os.Exit(1)
    }

    var pemPath string
    //flag.StringVar(&pemPath, "pem", pemPath_, "path to pem file")
    var keyPath string
    //flag.StringVar(&keyPath, "key", keyPath_, "path to key file")
    var https_port string
    pemPath,_ = viper.Get("pemPath").(string)
    keyPath,_ = viper.Get("keyPath").(string)
    https_port,_ = viper.Get("https_port").(string)
    var proto string
    flag.StringVar(&proto, "proto", "https", "Proxy protocol (http or https)")
    flag.Parse()
	
	
	
    if proto != "http" && proto != "https" {
        log.Fatal("Protocol must be either http or https")
    }
    server := &http.Server{
        Addr: ":"+https_port,
        Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            if r.Method == http.MethodConnect {
                handleTunneling(w, r)
            } else {
                handleHTTP(w, r)
            }
        }),
        // Disable HTTP/2.
        TLSNextProto: make(map[string]func(*http.Server, *tls.Conn, http.Handler)),
    }
    if proto == "http" {
        log.Fatal(server.ListenAndServe())
    } else {
        log.Fatal(server.ListenAndServeTLS(pemPath, keyPath))
    }
}
EOF
}

function add_config(){
cat <<'EOF' > /root/golang/data/config.json 
{
  "domainname": "<DOMAINNAME>",
  "http_port":"80",
  "www_dir":"/root/golang/www/",
  "https_port":"8888",
 
  "pemPath":"/root/.acme.sh/<DOMAINNAME>/<DOMAINNAME>.cer",
  "keyPath":"/root/.acme.sh/<DOMAINNAME>/<DOMAINNAME>.key"
}
EOF
}

function add_guard(){
cat <<'EOF' > /root/golang/guard.sh
#!/bin/bash

DAEMON_NAME="httpProxy"
DAEMON_HTTP="httpServer"

PID=`ps -ef | grep $DAEMON_NAME | grep -v grep`

if [ "$PID" == "" ];then
        echo "Proxy is not running..."
        nohup ./httpProxy >/dev/null 2>&1 & 
else
        echo "HTTPS Server Running..."
fi

PI2=`ps -ef | grep $DAEMON_HTTP | grep -v grep`

if [ "$PI2" == "" ];then
        echo "Proxy is not running..."
        nohup ./httpServer >/dev/null 2>&1 & 
else
        echo "HTTP Server Running..."
fi
EOF
}

function add_update_cert(){
cat <<'EOF' > /root/golang/update_cert.sh
#!/bin/sh
JQ_EXEC=`which jq`
FILE_PATH=./data/config.json
domainname=$(cat $FILE_PATH | ${JQ_EXEC} .domainname | sed 's/\"//g')
if [ "$domainname" == null ];then
       echo "cannot found 'domainname' in config.json"
else
        /root/.acme.sh/acme.sh --issue -d $domainname --webroot /root/golang/www
fi

PID=`ps -ef| grep httpProxy | grep -v grep|awk '{ print $2}'`
if [ "$PID" == "" ];then
        echo "PID == NULL"
        nohup ./httpProxy >/dev/null 2>&1 &
else
        echo $PID
        kill $PID
        nohup ./httpProxy >/dev/null 2>&1 &
fi
EOF
}

function add_start(){
cat <<'EOF' > /root/golang/start.sh
#/bin/bash
DAEMON_NAME="httpProxy"
DAEMON_HTTP="httpServer"
DAEMON_ADDR="/root/golang/"

PID=`ps -ef | grep $DAEMON_HTTP | grep -v grep`

if [ "$PID" == "" ];then
        echo "starting $DAEMON_HTTP ..."
        nohup $DAEMON_ADDR$DAEMON_HTTP >/dev/null 2>&1 &
fi

PID=`ps -ef | grep $DAEMON_NAME| grep -v grep`

if [ "$PID" == "" ];then
        echo "starting $DAEMON_NAME..."
        nohup $DAEMON_ADDR$DAEMON_NAME >/dev/null 2>&1 &
fi
EOF
}

function add_stop(){
cat <<'EOF' > /root/golang/stop.sh
#/bin/bash
DAEMON_NAME="httpProxy"
DAEMON_HTTP="httpServer"

PID=$(ps -ef|grep $DAEMON_HTTP|grep -v grep|awk '{print $2}')
if [ -z $PID ]; then
        echo "process $DAEMON_HTTP not exist"
        exit
else
        echo "process id: $PID"
        kill -9 ${PID}
        echo "process $DAEMON_HTTP killed"
fi

PID=$(ps -ef|grep $DAEMON_NAME|grep -v grep|awk '{print $2}')
if [ -z $PID ]; then
        echo "process $DAEMON_NAME not exist"
        exit
else
        echo "process id: $PID"
        kill -9 ${PID}
        echo "process $DAEMON_NAME killed"
fi
EOF
}

function create_files(){
    add_httpServer
    add_httpProxy
    add_guard
    add_config
    add_update_cert
    
    add_start
    add_stop
    
    chmod +x *.sh
}

function config_crontab(){
    echo '10 0 */10 * * "/root/golang/update_cert.sh" > /dev/null' >> /var/spool/cron/root
    echo '*/30 * * * * "/root/golang/guard.sh" > /dev/null' >> /var/spool/cron/root
}

function install(){
    pre_install
    create_files
    go_install
    acme_install
    #add_firewall
    
    config_crontab
}

install
