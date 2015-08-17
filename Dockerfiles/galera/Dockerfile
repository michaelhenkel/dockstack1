FROM ubuntu:14.04
ENV DEBIAN_FRONTEND noninteractive


EXPOSE 22 3306 4567 4568 4444 9200

RUN apt-get update
RUN apt-get install -y curl tcpdump iptables openssh-server rsync software-properties-common wget rsync lsof xinetd
RUN add-apt-repository 'deb http://releases.galeracluster.com/ubuntu trusty main'
RUN apt-get update
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 D669017EBC19DDBA
RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN apt-get update
RUN apt-get install -y puppet supervisor
RUN add-apt-repository 'deb http://ftp.cc.uoc.gr/mirrors/mariadb/repo/5.5/ubuntu trusty main'
RUN apt-get -q -y update
#RUN echo mariadb-galera-server-5.5 mysql-server/root_password password root | debconf-set-selections
#RUN echo mariadb-galera-server-5.5 mysql-server/root_password_again password root | debconf-set-selections 
RUN LC_ALL=en_US.utf8 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' -qqy install mariadb-galera-server galera mariadb-client
RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN echo 'root:ladakh1' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN sed -i 's/START=no/START=yes/' /etc/default/puppet
#COPY my.cnf /etc/mysql/my.cnf
COPY mysqlchk /etc/xinetd.d/mysqlchk
RUN echo "mysqlchk   9200/tcp" | tee -a /etc/services
RUN rm /usr/sbin/policy-rc.d; \
        rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV container docker
COPY puppet.conf /etc/puppet/puppet.conf
CMD ["/sbin/init"]
