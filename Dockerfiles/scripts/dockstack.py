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
from docker import Client
from docker.utils import create_host_config
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer
from pyroute2 import netns, IPDB, NetNS, NSPopen, IPRoute
from pprint import pprint, pformat

CONTAINER_LIB_DIR = '/var/lib/docker-volumes/'
CONTAINER_VOL_DIR = '/etc/dockerstack/volumes'

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
        logging.basicConfig(level=logging.INFO)
        logging.info("======= POST STARTED =======")
        logging.info(self.headers)
        self.data_string = self.rfile.read(int(self.headers['Content-Length']))
        data = json.loads(self.data_string)
        containerObject = ContainerObject(data)
        if self.path == '/checkDns':
            result = Dns(containerObject).check()
            self.request.sendall(result)
        if self.path == '/create':
            result = DockerControl(containerObject).create()
            result = NameSpace(containerObject).create()
            if isinstance(result,dict):
                result = json.dumps(result)
            self.request.sendall(result)
        if self.path == '/remove':
            dockerControl=DockerControl(containerObject).remove()
            nameSpace = NameSpace(containerObject).remove()
            self.request.sendall(json.dumps(containerObject.name + ':removed'))
        if self.path == '/updateDns':
            updateDns = Dns(containerObject).update()
            self.request.sendall(json.dumps(containerObject.name + ':dns updated'))
        if self.path == '/updatePuppet':
            updatePuppet = Puppet(containerObject).update()
            self.request.sendall(json.dumps(containerObject.name + ':puppet updated'))
          
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

class RegisterService:

    def __init__(self, containerObject):
        self.containerObject = containerObject
        self.containerDomain = containerObject.domain
        self.containerName = containerObject.name
        self.containerType = containerObject.type

    def configPuppet(self):
        dockerControl = DockerControl(self.containerObject)
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

    def registerContainer(self, action):
        print 'registering service: %s' % self.containerName
        envFile = CONTAINER_VOL_DIR + '/hieradata/common.yaml'    
        service = self.containerType
        node = self.containerName.encode('ascii','ignore')
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
        containerFqdn = self.containerName + '.' + self.containerDomain
        for line in siteFileList:
            if containerFqdn in line:
                lineNumber = counter
            counter = counter + 1
        print 'linenumber: %s' % lineNumber
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
                    print 'removing container'
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

        
        
        

class Puppet:
    def __init__(self,containerObject):
        self.containerObject = containerObject
        self.containerName = containerObject.name
        self.targetContainer = containerObject.targetContainer
        self.targetContainerObject = ContainerObject(self.targetContainer)
     
    def update(self):
        if self.containerObject.type != 'puppet' and self.containerObject.type != 'dns':
            print 'update puppet'
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
        self.targetContainer = containerObject.targetContainer
        self.targetContainerName = self.targetContainer.keys()[0]
        if self.targetContainer[self.targetContainerName]['props'].get('macAddress'):
            self.targetContainerMac = self.targetContainer[self.targetContainerName]['props']['macAddress']
        if self.targetContainer[self.targetContainerName]['props'].get('ipaddress'):
            self.targetContainerIp = self.targetContainer[self.targetContainerName]['props']['ipaddress']
        self.targetContainerDomain = self.targetContainer[self.targetContainerName]['domain']

    def check(self):
        dhcpFile = CONTAINER_VOL_DIR + '/dnsmasq.d/docker/dhcp/docker-dhcp-file'
        with open(dhcpFile,'r') as dnsFile:
            for line in dnsFile:
                if self.targetContainerName in line:
                    print 'line: %s' % line
                    dnsEntryDict = dict({'macAddress':line.split(',')[0],'container':line.split(',')[1],'ipAddress':line.split(',')[2]})
                    return json.dumps(dnsEntryDict)
        return json.dumps('result:No entry')

    def update(self):
        print 'updating dns entry'
        dnsContainer = self.containerObject.name
        dhcpFile = CONTAINER_VOL_DIR + '/dnsmasq.d/docker/dhcp/docker-dhcp-file'
        dnsFile = CONTAINER_VOL_DIR + '/dnsmasq.d/docker/dns/docker-dns-file'
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
        print nameString
        for container in containerList:
            if container['Names'][0]==nameString:
                containerId = container['Id']
        execKey = self.dockerCli.exec_create(containerId, cmd)
        execResult = self.dockerCli.exec_start(execKey['Id'])
        dockerInfo = self.dockerCli.exec_inspect(execKey['Id'])
        print execResult
        return execResult

    def create(self):
        image = self.containerObject.type
        name = self.containerObject.name
        domain = self.containerObject.domain
        hostname = self.containerObject.name
        if image == 'dns':
            dnsmasqConfVolume = CONTAINER_VOL_DIR + '/dnsmasq.conf:/etc/dnsmasq.conf'
            dnsmasqDVolume = CONTAINER_VOL_DIR + '/dnsmasq.d:/etc/dnsmasq.d'
            dVolumes = [dnsmasqConfVolume,dnsmasqDVolume]
        elif image == 'puppet':
            puppetConfVolume = CONTAINER_VOL_DIR + '/puppet-master.conf:/etc/puppet/puppet.conf'
            hieradataVolume = CONTAINER_VOL_DIR + '/hieradata:/etc/puppet/hieradata'
            siteVolume = CONTAINER_VOL_DIR + '/site.pp:/etc/puppet/manifests/site.pp'
            modulesVolume = CONTAINER_VOL_DIR + '/modules:/etc/puppet/modules'
            dVolumes = [puppetConfVolume,hieradataVolume,siteVolume,modulesVolume]
        else:
            puppetConfVolume = CONTAINER_VOL_DIR + '/puppet.conf:/etc/puppet/puppet.conf'
            authConfVolume = CONTAINER_VOL_DIR + '/auth.conf:/etc/puppet/auth.conf'
            dVolumes = [puppetConfVolume,authConfVolume]
        dnsList = []
        if isinstance(self.containerObject.dns,dict):
            for dnsServer in self.containerObject.dns.keys():
                dnsList.append(dnsServer)
        else:
            dnsList.append(self.containerObject.dns)
        dnsSearchList = [domain]
        command = '/sbin/init'
        host_config = create_host_config(binds=dVolumes,
                                         privileged=True,
                                         cap_add=['NET_ADMIN'],
                                         dns = dnsList,
                                         dns_search = dnsSearchList,
                                         network_mode = "none")
        container = self.dockerCli.create_container(image=image, name=name, command=command,
                                                    domainname=domain, hostname=name,
                                                    detach=True, host_config = host_config)
        self.dockerCli.start(container=container.get('Id'))
        containerInfo = self.dockerCli.inspect_container(container=container.get('Id'))
        containerPid = containerInfo['State']['Pid']
        pidPath = '/proc/' + str(containerPid) + '/ns/net'
        netNsPath = '/var/run/netns/' + name
        os.symlink(pidPath, netNsPath)
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

    def list(self):
        print(netns.listnetns())

    def remove(self):
        netns.remove(self.containerName)
        iface = self.containerName + 'veth0'
        subprocess.call(["ovs-vsctl", "del-port", "br0", iface])
        RegisterService(self.containerObject).registerContainer('remove')

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
        ns.close()
        subprocess.call(["ovs-vsctl", "add-port", "br0", iface])
        dockerControl = DockerControl(self.containerObject)
        if hasattr(self,'containerDhcp'):
            print 'running dhcp'
            dhcpCmd = 'dhclient eth0'
            dockerControl.runCmd(dhcpCmd)
        addressCmd = 'ip address show dev eth0'
        addressInfo = dockerControl.runCmd(addressCmd)
        addressInfoList = addressInfo.splitlines()
        macAddressInfo = addressInfoList[1].split()[1]
        ipAddressInfo = addressInfoList[2].split()[1]
        ipAddressInfoDict = dict({'containerName':self.containerName,'macAddress':macAddressInfo,'ipAddress':ipAddressInfo})
        registerService = RegisterService(self.containerObject)
        registerService.registerContainer('add')
        if self.containerType == 'puppet':
            registerService.configPuppet()
        return json.dumps(ipAddressInfoDict)

    def execCmd(self, cmd):
        cmdList = cmd.split()
        nsp = NSPopen(self.nSname, cmdList , stdout=subprocess.PIPE)
        nsp.wait()
        nsp.release()
        

parser = argparse.ArgumentParser(description='updates hiera file')
parser.add_argument('--nSname', metavar='f',
                   help='name space name')
parser.add_argument('--action', metavar='f',
                   help='list/create/remove')
parser.add_argument('--ifacePair', metavar='f',
                   help='interface pair name')
parser.add_argument('--ipaddress', metavar='f',
                   help='peer interface ip address')
parser.add_argument('--cmd', metavar='f',
                   help='exec cmd in ns')
parser.add_argument('--macAddress', metavar='f',
                   help='macAdress of interface')
args = parser.parse_args()
action = args.action
if args.nSname:
    nSname = args.nSname
if args.ifacePair:
    iface, ifacePeer = args.ifacePair.split(':')
if args.ipaddress:
    ipaddress = args.ipaddress
if args.cmd:
    cmd = args.cmd
if args.macAddress:
    macAddress = args.macAddress

if action == 'listNS': 
    nameSpace=NameSpace().list()
if action == 'createNS':
    nameSpace=NameSpace(nSname).create()
if action == 'removeNS':
    nameSpace=NameSpace(nSname).remove()
if action == 'createIfPair':
    nameSpace=NameSpace(nSname).create(iface,ifacePeer)
if action == 'removeIfPair':
    nameSpace=NameSpace(nSname).remove(iface,ifacePeer)
if action == 'addIp':
    nameSpace=NameSpace(nSname).addIp(ifacePeer, ipaddress)
if action == 'exec':
    nameSpace=NameSpace(nSname).execCmd(cmd)

if action == 'aio':
    nameSpace=NameSpace(nSname).remove()
    #nameSpace=NameSpace(nSname).create()
    #time.sleep(2)
    NameSpace(nSname).create(iface,ifacePeer)
    #if args.macAddress:
    #    nameSpace.createInterfacePair(iface,ifacePeer,macAddress)
    #else:
    #    nameSpace=NameSpace(nSname).createInterfacePair(iface,ifacePeer)
    #if args.ipaddress:
    #    nameSpace.addIp(ifacePeer, ipaddress)
    #if args.cmd:
    #    nameSpace.execCmd(cmd)

if __name__ == "__main__":
    HOST, PORT = "192.168.1.102", 3288
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, Handler)
    print "Serving at: http://%s:%s" % (HOST, PORT)
    httpd.serve_forever()

    #server = SocketServer.TCPServer((HOST, PORT), MyTCPHandler)
    #server.serve_forever()
