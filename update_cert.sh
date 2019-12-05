#!/bin/sh
JQ_EXEC=`which jq`
FILE_PATH=config.json
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