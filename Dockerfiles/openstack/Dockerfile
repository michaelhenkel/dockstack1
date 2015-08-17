FROM ubuntu:14.04
ENV DEBIAN_FRONTEND noninteractive


EXPOSE 22 80 443 3306 5673 5000 35357 5672 9696 9292 9191 8773 8774 8776 

RUN sed -i 's/^# \(.*-backports\s\)/\1/g' /etc/apt/sources.list
RUN echo "deb http://10.0.0.1/contrail/ contrail main" >> /etc/apt/sources.list
COPY contrail-apt-preference /etc/apt/preferences.d/contrail-apt-preference
RUN apt-get update
RUN apt-get install -y --force-yes curl tcpdump iptables openssh-server supervisor wget psmisc rsyslog python-iniparse
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN apt-get install ubuntu-cloud-keyring
RUN echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
  "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
RUN apt-get update
RUN apt-get install --force-yes -y puppet python-mysqldb rabbitmq-server keystone python-keystoneclient glance \
                       python-glanceclient neutron-server neutron-plugin-ml2 \ 
                       python-neutronclient openstack-dashboard apache2 \
                       libapache2-mod-wsgi memcached python-memcache \
                       cinder-api cinder-scheduler python-cinderclient lvm2 \
                       nova-api nova-cert nova-conductor nova-consoleauth \
                       nova-novncproxy nova-scheduler python-novaclient python-openstackclient neutron-plugin-contrail
#neutron-plugin-contrail
#RUN sed -i 's/START=no/START=yes/' /etc/default/puppet
#RUN apt-get update
#RUN apt-get install --force-yes -y neutron-plugin-contrail
RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN echo 'root:ladakh1' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN rm /usr/sbin/policy-rc.d; \
        rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV container docker
RUN puppet agent --enable
CMD ["/sbin/init"]
