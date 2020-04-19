#基于centos镜像
FROM centos

#维护人的信息
MAINTAINER The GoProxy Project <okjjhfj111@126.com>

#安装软件包
RUN yum -y install curl git vim

#开启80和8888端口
EXPOSE 80
EXPOSE 8888

#复制该脚本至镜像中，并修改其权限
ADD install.sh /root/install.sh
RUN chmod +x /root/install.sh
RUN ./root/install.sh
