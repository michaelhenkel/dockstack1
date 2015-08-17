# Use phusion/baseimage as base image. To make your builds
# reproducible, make sure you lock down to a specific version, not
# to `latest`! See
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
# for a list of version numbers.
FROM ubuntu:14.04

# Use baseimage-docker's init system.
#CMD ["/sbin/my_init"]
CMD ["/usr/bin/supervisord"]

# ...put your own build instructions here...

#COPY rt /etc/dhcp/dhclient-exit-hooks.d/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 22

# Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y python-software-properties curl tcpdump iptables openssh-server \
       software-properties-common supervisor puppet rsync && \
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db && \
  wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb && \
  add-apt-repository 'deb http://mirror.jmu.edu/pub/mariadb/repo/5.5/ubuntu trusty main' && \
  dpkg -i puppetlabs-release-trusty.deb && \
  apt-get update && \
  apt-get install -y puppet mariadb-galera-server galera && \
  mkdir -p /var/run/sshd /var/log/supervisor && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN echo 'root:screencast' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
