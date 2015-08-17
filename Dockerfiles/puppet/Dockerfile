FROM ubuntu:14.04
ENV DEBIAN_FRONTEND noninteractive

#CMD ["/usr/bin/supervisord"]


EXPOSE 22 80 443 3306

RUN sed -i 's/^# \(.*-backports\s\)/\1/g' /etc/apt/sources.list
RUN mkdir -p /etc/puppet
COPY hiera.yaml /etc/puppet/hiera.yaml
COPY modules /etc/puppet/modules
RUN apt-get update
RUN apt-get install -y curl tcpdump iptables openssh-server wget apache2 psmisc ruby-dev ruby ruby-passenger dnsmasq
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN apt-get update
RUN apt-get install -y puppetmaster-passenger
#RUN sed -i 's/START=no/START=yes/' /etc/default/puppet
RUN echo 'root:ladakh1' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN rm /usr/sbin/policy-rc.d; \
        rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV container docker
#COPY puppet.conf /etc/puppet/puppet.conf
CMD ["/sbin/init"]
