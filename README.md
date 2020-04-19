# GoProxy
  HTTPS Proxy For CentOS. Written in Golang

## install

`curl https://raw.githubusercontent.com/FigoHu/GoProxy/master/install.sh | sh`

## Usage
Step 1. Edit config.json file. Replace <DOMAINNAME> with your server's real domain name (for Let's Encrypt cert need).  
  ```
  {  
      "domainname": "<DOMAINNAME>",  
      "http_port":"80",  
      "www_dir":"/root/golang/www/",  
      "https_port":"8888",  
      "pemPath":"/root/.acme.sh/<DOMAINNAME>/<DOMAINNAME>.cer",  
      "keyPath":"/root/.acme.sh/<DOMAINNAME>/<DOMAINNAME>.key"  
}
  ```
Step 2.   
  ```
  # cd ~/golang
  # ./start.sh
  # ./update_cert.sh
  # ./guard.sh
  ```
  
