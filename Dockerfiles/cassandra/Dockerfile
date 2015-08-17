FROM ubuntu:14.04
ENV DEBIAN_FRONTEND noninteractive

#CMD ["/usr/bin/supervisord"]


EXPOSE 22 8103 9160 9042 53431 7000 56221 7199 2181 49613 3888 44145 57886
RUN echo "deb http://10.0.0.1/contrail/ contrail main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y --force-yes curl tcpdump iptables openssh-server rsync software-properties-common wget contrail-openstack-database libssl0.9.8
RUN apt-get update
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN apt-get update
RUN apt-get install -y puppet supervisor
RUN apt-get -q -y update
RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN sed -i 's/START=no/START=yes/' /etc/default/puppet
RUN echo 'root:ladakh1' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN rm /usr/sbin/policy-rc.d; \
	rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV container docker
COPY puppet.conf /etc/puppet/puppet.conf

CMD ["/sbin/init"]
