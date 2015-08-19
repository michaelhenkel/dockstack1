#!/usr/bin/python
import json
import argparse
import subprocess
import sys
import time
import socket
import daemon
import SocketServer
import logging
import cgi
import threading
import os
import yaml
from shutil import copy, copytree, rmtree
from docker import Client
from docker.utils import create_host_config
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer
from pyroute2 import netns, IPDB, NetNS, NSPopen, IPRoute
from pyroute2.netlink.rtnl.req import IPRouteRequest
from pprint import pprint, pformat

CONTAINER_LIB_DIR = '/var/lib/docker-volumes/'
CONTAINER_VOL_DIR = '/etc/dockerstack/volumes'
CONTAINER_CONF_DIR = '/etc/dockerstack/configs'

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if format == 'html':
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write("body")
        elif format == 'json':
            self.request.sendall(json.dumps({'path':self.path}))
        else:
            self.request.sendall("%s\t%s" %('path', self.path))
        return

    def do_POST(self):
        if not os.path.isdir('/var/run/netns'):
           os.makedirs('/var/run/netns')
        #logging.basicConfig(level=logging.INFO)
        #logging.info("======= POST STARTED =======")
        #logging.info(self.headers)
        self.data_string = self.rfile.read(int(self.headers['Content-Length']))
        data = json.loads(self.data_string)
        containerObject = ContainerObject(data)
        if self.path == '/checkDns':
            result = Dns(containerObject).check()
            self.request.sendall(result)
        if self.path == '/start':
            result = DockerControl(containerObject).start()
            result = NameSpace(containerObject).create()
            if isinstance(result,dict):
                result = json.dumps(result)
            self.request.sendall(result)
        if self.path == '/stop':
            result = DockerControl(containerObject).stop()
            result = NameSpace(containerObject).remove()
            if isinstance(result,dict):
                result = json.dumps(result)
            self.request.sendall(result)
        if self.path == '/create':
            result = DockerControl(containerObject).create()
            result = NameSpace(containerObject).create()
            if isinstance(result,dict):
                result = json.dumps(result)
            if containerObject.type == 'puppet':
                puppet = Puppet(containerObject)
                puppet.configPuppet()
            Puppet(containerObject).registerContainer('add')
            pprint(json.dumps({'container':containerObject.name,
                                 'service':containerObject.type,
                                 'ip':containerObject.ip,
                                 'mac':containerObject.mac,
                                 'status':'successfully created'}))
            self.request.sendall(result)
        if self.path == '/remove':
            dockerControl=DockerControl(containerObject).remove()
            nameSpace = NameSpace(containerObject).remove()
            Puppet(containerObject).registerContainer('remove')
            self.request.sendall(json.dumps(containerObject.name + ':removed'))
        if self.path == '/updateDns':
            updateDns = Dns(containerObject).update()
            self.request.sendall(json.dumps(containerObject.name + ':dns updated'))
        if self.path == '/updatePuppet':
            puppet = Puppet(containerObject)
            updatePuppet = puppet.update()
            self.request.sendall(json.dumps(containerObject.name + ':puppet updated'))
        if self.path == '/syncPuppet':
            Puppet(containerObject).syncPuppet()
            self.request.sendall(json.dumps(containerObject.name + ':puppet synced'))
          
        #result = containerObject.show()
        #self.request.sendall(json.dumps(result))

class ContainerObject:
    def __init__(self, data):
        self.data = data
        self.name = data.keys()[0]
        self.type = data[self.name]['type']
        self.domain = data[self.name]['domain']
        if data[self.name]['props'].get('ipaddress'):
            self.ip = data[self.name]['props']['ipaddress']
        if data[self.name]['props'].get('gateway'):
            self.gateway = data[self.name]['props']['gateway']
        if data[self.name]['props'].get('macAddress'):
            self.mac = data[self.name]['props']['macAddress']
        if data[self.name]['dns']:
            self.dns = data[self.name]['dns']
        if data[self.name]['puppet']:
            self.puppet = data[self.name]['puppet']
        if data[self.name].get('targetContainer'):
            self.targetContainer = data[self.name]['targetContainer']
        if data[self.name]['props'].get('dhcp'):
            self.dhcp = data[self.name]['props']['dhcp']

    def show(self):
        return self.data

class Puppet:

    def __init__(self, containerObject):
        self.containerObject = containerObject
        self.containerDomain = containerObject.domain
        self.containerName = containerObject.name
        self.containerType = containerObject.type
        if hasattr(containerObject, 'targetContainer'):
            self.targetContainer = containerObject.targetContainer
            self.targetContainerObject = ContainerObject(self.targetContainer)

    def configPuppet(self):
        dockerControl = DockerControl(self.containerObject)
        #copy(CONTAINER_VOL_DIR + '/site.pp', CONTAINER_VOL_DIR + '/' + self.containerName + '/manifests/site.pp')
        #copy(CONTAINER_VOL_DIR + '/hieradata/common.yaml', CONTAINER_VOL_DIR + '/' + self.containerName + '/hieradata/common.yaml')
        puppetFqdn = self.containerName + '.' + self.containerDomain
        preRunCmdList = []
        preRunCmdList.append('service apache2 stop')
        preRunCmdList.append('puppet cert generate '+puppetFqdn)
        preRunCmdList.append('sed -i "s/.*SSLCertificateFile.*/        SSLCertificateFile      \/var\/lib\/puppet\/ssl\/certs\/'+puppetFqdn+'.pem/g" /etc/apache2/sites-enabled/puppetmaster.conf')
        preRunCmdList.append('sed -i "s/.*SSLCertificateKeyFile.*/        SSLCertificateKeyFile      \/var\/lib\/puppet\/ssl\/private_keys\/'+puppetFqdn+'.pem/g" /etc/apache2/sites-enabled/puppetmaster.conf')
        preRunCmdList.append('service apache2 start')
        if preRunCmdList != '':
            for cmd in preRunCmdList:
                print cmd
                dockerControl.runCmd(cmd)

    def syncPuppet(self):
        copy(CONTAINER_VOL_DIR + '/site.pp', CONTAINER_VOL_DIR + '/' + self.containerName + '/manifests/site.pp')
        copy(CONTAINER_VOL_DIR + '/hieradata/common.yaml', CONTAINER_VOL_DIR + '/' + self.containerName + '/hieradata/common.yaml')

    def registerContainer(self, action):
        envFile = CONTAINER_VOL_DIR + '/hieradata/common.yaml'    
        service = self.containerObject.type
        node = self.containerObject.name.encode('ascii','ignore')
        f = open(envFile,'r')
        yaml_file = f.read().strip()
        yaml_object=yaml.load(yaml_file)
        if action == 'add':
            if service not in yaml_object['registered_services']:
                yaml_object['registered_services'][service]=[]
            yaml_object['registered_services'][service].append(node)
        elif action == 'remove':
            yaml_object['registered_services'][service].remove(node)
        outfile = file(envFile,'w')
        yaml.dump(yaml_object, outfile, default_flow_style=False)
        f.close

        siteFile = CONTAINER_VOL_DIR + '/site.pp'
        f = open(siteFile,'r')
        siteFileList = f.read().splitlines()
        counter = 0
        lineNumber = ''
        containerFqdn = self.containerObject.name + '.' + self.containerObject.domain
        for line in siteFileList:
            if containerFqdn in line:
                lineNumber = counter
            counter = counter + 1
        if lineNumber == '':
            if action == 'add':
                if self.containerType == 'haproxy':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::mymod::ha': }")
                    siteFileList.append("  class { '::mymod::ka': }")
                    siteFileList.append("}")
                if self.containerType == 'galera':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::mymod::gal': }")
                    siteFileList.append("}")
                if self.containerType == 'openstack':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::mymod::os': }")
                    siteFileList.append("}")
                if self.containerType == 'cassandra':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::contrail::common': }")
                    siteFileList.append("  class { '::contrail::database': }")
                    siteFileList.append("}")
                if self.containerType == 'config':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::contrail::common': }")
                    siteFileList.append("  class { '::contrail::config': }")
                    siteFileList.append("}")
                if self.containerType == 'collector':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::contrail::common': }")
                    siteFileList.append("  class { '::contrail::collector': }")
                    siteFileList.append("}")
                if self.containerType == 'control':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::contrail::common': }")
                    siteFileList.append("  class { '::contrail::control': }")
                    siteFileList.append("}")
                if self.containerType == 'webui':
                    siteFileList.append("node '" + containerFqdn + "' {")
                    siteFileList.append("  class { '::contrail::common': }")
                    siteFileList.append("  class { '::contrail::webui': }")
                    siteFileList.append("}")
        else:
            if self.containerType == 'haproxy':
                print 'container in list'
                if action == 'add':
                    print 'adding container'
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::mymod::ha': }"
                    siteFileList[lineNumber+2] = "  class { '::mymod::ka': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'galera':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::mymod::gal': }"
                    siteFileList[lineNumber+2] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'openstack':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::mymod::os': }"
                    siteFileList[lineNumber+2] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'cassandra':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::contrail::common': }"
                    siteFileList[lineNumber+2] = "  class { '::contrail::database': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'config':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::contrail::common': }"
                    siteFileList[lineNumber+2] = "  class { '::contrail::config': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'collector':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::contrail::common': }"
                    siteFileList[lineNumber+2] = "  class { '::contrail::collector': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'control':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::contrail::common': }"
                    siteFileList[lineNumber+2] = "  class { '::contrail::control': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
            if self.containerType == 'webui':
                if action == 'add':
                    siteFileList[lineNumber] = "node '" + containerFqdn + "' {"
                    siteFileList[lineNumber+1] = "  class { '::contrail::common': }"
                    siteFileList[lineNumber+2] = "  class { '::contrail::webui': }"
                    siteFileList[lineNumber+3] = "}"
                if action == 'remove':
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
                    siteFileList.pop(lineNumber)
        f=open(siteFile,'w')
        for item in siteFileList:
            f.write("%s\n" % item)
        f.close()
     
    def update(self):
        if self.targetContainerObject.type != 'puppet' and self.targetContainerObject.type != 'dns':
            cmd = 'service puppet stop'
            dockerControl = DockerControl(self.targetContainerObject).runCmd(cmd)
            cmd = 'rm -rf /var/lib/puppet/ssl'
            dockerControl = DockerControl(self.targetContainerObject).runCmd(cmd)
            containerFqdn = self.targetContainerObject.name + '.' + self.targetContainerObject.domain 
            cmd = 'puppet cert clean ' + containerFqdn
            dockerControl = DockerControl(self.containerObject).runCmd(cmd)
            cmd = 'service puppet start'
            dockerControl = DockerControl(self.targetContainerObject).runCmd(cmd)
        return self.containerObject

class Dns:
    def __init__(self,containerObject):
        self.containerObject = containerObject
        if not hasattr(containerObject,'targetContainer'):
            self.targetContainer = containerObject
            self.targetContainerName = self.targetContainer.name
            self.targetContainerMac = self.targetContainer.mac
            self.targetContainerIp = self.targetContainer.ip
            self.targetContainerDomain = self.targetContainer.domain
        else:
            self.targetContainer = containerObject.targetContainer
            self.targetContainerName = self.targetContainer.keys()[0]
            if self.targetContainer[self.targetContainerName]['props'].get('macAddress'):
                self.targetContainerMac = self.targetContainer[self.targetContainerName]['props']['macAddress']
            if self.targetContainer[self.targetContainerName]['props'].get('ipaddress'):
                self.targetContainerIp = self.targetContainer[self.targetContainerName]['props']['ipaddress']
            self.targetContainerDomain = self.targetContainer[self.targetContainerName]['domain']

    def check(self):
        dhcpFile = CONTAINER_VOL_DIR + '/' + self.containerObject.name + '/dnsmasq.d/docker/dhcp/docker-dhcp-file'
        with open(dhcpFile,'r') as dnsFile:
            for line in dnsFile:
                if self.targetContainerName in line:
                    dnsEntryDict = dict({'macAddress':line.split(',')[0],'container':line.split(',')[1],'ipAddress':line.split(',')[2]})
                    return json.dumps(dnsEntryDict)
        return json.dumps('result:No entry')

    def update(self):
        dnsContainer = self.containerObject.name
        dhcpFile = CONTAINER_CONF_DIR + '/dnsmasq.d/docker/dhcp/docker-dhcp-file'
        dnsFile = CONTAINER_CONF_DIR +  '/dnsmasq.d/docker/dns/docker-dns-file'
        f = open(dhcpFile)
        dhcpString = f.read()
        f.close()
        dhcpStringList = dhcpString.splitlines()
        f = open(dnsFile)
        dnsString = f.read()
        f.close()
        dnsStringList = dnsString.splitlines()
        newDhcpEntry = self.targetContainerMac + ',' + self.targetContainerName + ',' + self.targetContainerIp.split('/')[0] + ',infinite'
        newDnsEntry = self.targetContainerIp.split('/')[0] + ' ' + self.targetContainerName + '.' + self.targetContainerDomain 
        counter = 0
        lineNumber = ''
        for line in dhcpStringList:
            if self.targetContainerName in line:
                lineNumber = counter
            counter = counter + 1
        if lineNumber:
            dhcpStringList[lineNumber] = newDhcpEntry
            f = open(dhcpFile,'w')
            for item in dhcpStringList:
                f.write("%s\n" % item)
            f.close()
        else:
            dhcpStringList.append(newDhcpEntry)
            f = open(dhcpFile,'w')
            for item in dhcpStringList:
                f.write("%s\n" % item)
            f.close()

        counter = 0
        lineNumber = ''
        for line in dnsStringList:
            if self.targetContainerName in line:
                lineNumber = counter
            counter = counter + 1
        if lineNumber:
            dnsStringList[lineNumber] = newDnsEntry
            f = open(dnsFile,'w')
            for item in dnsStringList:
                f.write("%s\n" % item)
            f.close()
        else:
            dnsStringList.append(newDnsEntry)
            f = open(dnsFile,'w')
            for item in dnsStringList:
                f.write("%s\n" % item)
            f.close()
        copy(dhcpFile, CONTAINER_VOL_DIR + '/' + dnsContainer + '/dnsmasq.d/docker/dhcp/docker-dhcp-file')
        copy(dnsFile, CONTAINER_VOL_DIR + '/' + dnsContainer + '/dnsmasq.d/docker/dns/docker-dns-file')
        cmd = 'pkill -x -HUP dnsmasq'
        dockerControl = DockerControl(self.containerObject)
        dockerControl.runCmd(cmd)
        return json.dumps({'dnsUpdate':'dns'})
        
            
class DockerControl:
    def __init__(self,containerObject):
        self.containerObject = containerObject
        self.dockerCli = Client(base_url='unix://var/run/docker.sock')

    def remove(self):
        labelString = 'name=' + self.containerObject.name
        labelDict = [labelString]
        label = dict({'label':labelDict})
        nameString = '/' + self.containerObject.name
        containerList= self.dockerCli.containers()
        for container in containerList:
            if container['Names'][0]==nameString:
                containerId = container['Id']
        self.dockerCli.stop(container=containerId)
        self.dockerCli.remove_container(container=containerId)

    def runCmd(self, cmd):
        nameString = '/' + self.containerObject.name
        containerList= self.dockerCli.containers()
        for container in containerList:
            if container['Names'][0]==nameString:
                containerId = container['Id']
        execKey = self.dockerCli.exec_create(containerId, cmd)
        execResult = self.dockerCli.exec_start(execKey['Id'])
        dockerInfo = self.dockerCli.exec_inspect(execKey['Id'])
        return execResult


    def create(self):
        image = self.containerObject.type
        name = self.containerObject.name
        domain = self.containerObject.domain
        hostname = self.containerObject.name
        directory = CONTAINER_VOL_DIR + '/' + name
        if os.path.isdir(directory):
            rmtree(directory)
        os.makedirs(directory)
        if image == 'dns':
            copy(CONTAINER_CONF_DIR + '/dnsmasq.conf', directory + '/dnsmasq.conf')
            copytree(CONTAINER_CONF_DIR + '/dnsmasq.d', directory + '/dnsmasq.d')
            dnsmasqConfVolume = directory + '/dnsmasq.conf:/etc/dnsmasq.conf'
            dnsmasqDVolume = directory+ '/dnsmasq.d:/etc/dnsmasq.d'
            dVolumes = [dnsmasqConfVolume,dnsmasqDVolume]
        elif image == 'puppet':
            puppetConfVolume = CONTAINER_VOL_DIR + '/puppet-master.conf:/etc/puppet/puppet.conf'
            hieradataVolume = CONTAINER_VOL_DIR + '/hieradata:/etc/puppet/hieradata'
            siteVolume = CONTAINER_VOL_DIR + '/site.pp:/etc/puppet/manifests/site.pp'
            modulesVolume = CONTAINER_VOL_DIR + '/modules:/etc/puppet/modules'
            dVolumes = [puppetConfVolume,hieradataVolume,siteVolume,modulesVolume]
        else:
            copy(CONTAINER_CONF_DIR + '/puppet.conf', directory + '/puppet.conf')
            copy(CONTAINER_CONF_DIR + '/auth.conf', directory + '/auth.conf')
            puppetConfVolume = directory + '/puppet.conf:/etc/puppet/puppet.conf'
            authConfVolume = directory + '/auth.conf:/etc/puppet/auth.conf'
            dVolumes = [puppetConfVolume,authConfVolume]
        dnsList = []
        if isinstance(self.containerObject.dns,dict):
            for dnsServer in self.containerObject.dns.keys():
                dnsServerString = self.containerObject.dns[dnsServer]['ipaddress'].split('/')[0]
                dnsList.append(dnsServerString)
        else:
            dnsList.append(self.containerObject.dns)
        dnsSearchList = [domain]
        command = '/sbin/init'
        host_config = create_host_config(privileged=True,
                                         cap_add=['NET_ADMIN'],
                                         dns = dnsList,
                                         dns_search = dnsSearchList,
                                         binds=dVolumes,
                                         network_mode = "none")
        container = self.dockerCli.create_container(image=image, name=name, command=command,
                                                    #domainname=domain, hostname=name, volumes = dVolumes,
                                                    domainname=domain, hostname=name,
                                                    detach=True, host_config = host_config)
        self.dockerCli.start(container=container.get('Id'))
        containerInfo = self.dockerCli.inspect_container(container=container.get('Id'))
        containerPid = containerInfo['State']['Pid']
        pidPath = '/proc/' + str(containerPid) + '/ns/net'
        netNsPath = '/var/run/netns/' + name
        os.symlink(pidPath, netNsPath)
        return containerInfo

    def start(self):
        nameString = '/' + self.containerObject.name
        containerList= self.dockerCli.containers(all=True)
        for container in containerList:
            if container['Names'][0]==nameString:
                containerId = container['Id']
        self.dockerCli.start(container=containerId)
        containerInfo = self.dockerCli.inspect_container(container=containerId)
        containerPid = containerInfo['State']['Pid']
        pidPath = '/proc/' + str(containerPid) + '/ns/net'
        netNsPath = '/var/run/netns/' + self.containerObject.name
        os.symlink(pidPath, netNsPath)
        return containerInfo

    def stop(self):
        nameString = '/' + self.containerObject.name
        containerList= self.dockerCli.containers()
        for container in containerList:
            if container['Names'][0]==nameString:
                containerId = container['Id']
        self.dockerCli.stop(container=containerId)
        containerInfo = self.dockerCli.inspect_container(container=containerId)
        return containerInfo
        

class NameSpace:
    def __init__(self,containerObject):
        self.containerObject = containerObject
        self.containerName = containerObject.name
        if hasattr(containerObject,'ip'):
            self.containerIp = containerObject.ip
        if hasattr(containerObject,'mac'):
            self.containerMac = containerObject.mac
        self.containerType = containerObject.type
        if hasattr(containerObject,'dhcp'):
            self.containerDhcp = containerObject.dhcp
        if hasattr(containerObject,'gateway'):
            self.containerGateway = containerObject.gateway

    def list(self):
        print(netns.listnetns())

    def remove(self):
        netns.remove(self.containerName)
        iface = self.containerName + 'veth0'
        subprocess.call(["ovs-vsctl", "del-port", "br0", iface])

    def stop(self):
        netns.remove(self.containerName)
        iface = self.containerName + 'veth0'
        subprocess.call(["ovs-vsctl", "del-port", "br0", iface])

    def create(self):
        iface = self.containerName + 'veth0'
        ifacePeer = self.containerName + 'veth1'
        ip_main = IPDB()
        ip_sub  = IPDB(nl=NetNS(self.containerName))
        ip_main.create(ifname=iface, kind='veth', peer=ifacePeer).commit()
        with ip_main.interfaces[ifacePeer] as veth:
            veth.net_ns_fd = self.containerName
        with ip_main.interfaces[iface] as veth:
            veth.up()
        ip_main.release()
        with ip_sub.interfaces[ifacePeer] as veth:
            #if not self.containerDhcp:
            if not hasattr(self,'containerDhcp'):
                veth.add_ip(self.containerIp)
            if hasattr(self,'containerMac'):
                veth.address = self.containerMac
        ip_sub.release()
        ns = NetNS(self.containerName)
        idx = ns.link_lookup(ifname=ifacePeer)[0]
        ns.link('set', index=idx, net_ns_fs=self.containerName, ifname='eth0')
        ns.link('set', index=idx, net_ns_fs=self.containerName, state='up')
        if hasattr(self,'containerGateway'):
            request = {"dst": "0.0.0.0/0",
                       "gateway": self.containerGateway}
            ns.route("add", **IPRouteRequest(request))
        ns.close()
        subprocess.call(["ovs-vsctl", "add-port", "br0", iface])
        dockerControl = DockerControl(self.containerObject)
        if hasattr(self,'containerDhcp'):
            dhcpCmd = 'dhclient eth0'
            dockerControl.runCmd(dhcpCmd)
        addressCmd = 'ip address show dev eth0'
        addressInfo = dockerControl.runCmd(addressCmd)
        addressInfoList = addressInfo.splitlines()
        macAddressInfo = addressInfoList[1].split()[1]
        ipAddressInfo = addressInfoList[2].split()[1]
        ipAddressInfoDict = dict({'containerName':self.containerName,'macAddress':macAddressInfo,'ipAddress':ipAddressInfo})
        return json.dumps(ipAddressInfoDict)

    def execCmd(self, cmd):
        cmdList = cmd.split()
        nsp = NSPopen(self.nSname, cmdList , stdout=subprocess.PIPE)
        nsp.wait()
        nsp.release()
        

import socket
import fcntl
import struct

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

parser = argparse.ArgumentParser(description='updates hiera file')
parser.add_argument('--ipaddress', metavar='f',
                   help='ip address to listen on')
parser.add_argument('--interface', metavar='f',
                   help='interface to listen on')
parser.add_argument('--port', metavar='f',
                   help='port to listen on')
args = parser.parse_args()

if args.ipaddress:
    HOST = args.ipaddress

if args.interface:
    HOST = get_ip_address(args.interface)

if args.port:
    PORT = args.port
else:
    PORT = 3288

if not args.ipaddress and not args.interface:
    HOST = get_ip_address('eth0')

if __name__ == "__main__":
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, Handler)
    print "Serving at: http://%s:%s" % (HOST, PORT)
    httpd.serve_forever()
