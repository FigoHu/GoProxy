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