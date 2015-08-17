import json
import yaml
import socket
import sys
import argparse
import httplib, urllib2
from pprint import pprint
from time import sleep
from docker import Client
ENV_FILE='/etc/dockerstack/volumes/hieradata/common.yaml'
PORT = '3288'

class SendHTTPData:
   def __init__(self, data, method, host, action):
       self.connection = 'http://' + host + ':' + PORT + '/' + action
       self.data = data

   def send(self):
       req = urllib2.Request(self.connection)
       req.add_header('Content-Type', 'application/json')
       response = urllib2.urlopen(req, json.dumps(self.data))
       return json.loads(response.read())
       
class ContainerObject:
    def __init__(self, containerName):
        self.containerName = containerName
        f = open(ENV_FILE,'r')
        yaml_file = f.read().strip()
        self.yaml_object=yaml.load(yaml_file)

    def getContainerService(self,containerName):
        for key,value in self.yaml_object['services'].items():
            for v2 in value.keys():
                if v2 == containerName:
                    return key

    def getService(self,service):
        registeredServiceList = {}
        if self.yaml_object['registered_services'].get(service):
            for serviceServer in self.yaml_object['services'][service]:
                for registered_service in self.yaml_object['registered_services'][service]:
                    if serviceServer == registered_service:
                        registeredServiceList[serviceServer]=self.yaml_object['services'][service].get(serviceServer)
        return registeredServiceList
          
    def create(self):
        containerName = self.containerName
        containerType = self.getContainerService(containerName)
        containerDns = self.getService('dns')
        if not containerDns:
            containerDns = self.yaml_object['common']['dnsServer']
        containerPuppet = self.getService('puppet')
        if not containerPuppet:
            containerPuppet = self.yaml_object['common']['puppetServer']
        containerProps = self.yaml_object['services'][containerType][containerName]
        containerDomain = self.yaml_object['common']['domain']
        containerObject = { containerName:
                               { 'props': containerProps,
                                 'type': containerType,
                                 'dns': containerDns ,
                                 'puppet' : containerPuppet,
                                 'domain' : containerDomain
                               }
                          }
        return containerObject

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='updates hiera file')
    parser.add_argument('--action', metavar='f',
                   help='list/create/remove')
    parser.add_argument('--name', metavar='f',
                   help='name of Container')
    parser.add_argument('--type', metavar='f',
                   help='type of Container')
    args = parser.parse_args()

    containerObject = ContainerObject(args.name).create()
    if 'ipaddress' not in containerObject[args.name]['props']:
        for dnsServer in containerObject[args.name]['dns'].keys():
            dnsContainerObject = ContainerObject(dnsServer).create()
            dnsContainerObject[dnsServer]['targetContainer']= containerObject
            containerObject[args.name]['props']['dhcp'] = True
            result = SendHTTPData(data=dnsContainerObject,method='POST',host=dnsContainerObject[dnsServer]['props']['host'],action='checkDns').send()
            if 'ipAddress' in result:
                containerObject[args.name]['props']['ipaddress'] = result['ipAddress']
                containerObject[args.name]['props']['macAddress'] = result['macAddress']


    if args.action == 'create':
        ipAddressInfo = SendHTTPData(data=containerObject,method='POST',host=containerObject[args.name]['props']['host'],action=args.action).send()
        if ipAddressInfo.get('macAddress'):
            containerObject[args.name]['props']['macAddress'] = ipAddressInfo['macAddress']
        if ipAddressInfo.get('ipAddress'):
            containerObject[args.name]['props']['ipaddress'] = ipAddressInfo['ipAddress']
        if containerObject[args.name].get('dns'):
            if isinstance(containerObject[args.name]['dns'],dict):
                for dnsServer in containerObject[args.name]['dns'].keys():
                    dnsContainerObject = ContainerObject(dnsServer).create()
                    dnsContainerObject[dnsServer]['targetContainer']= containerObject
                    containerObject[args.name]['props']['dhcp'] = True
                    result = SendHTTPData(data=dnsContainerObject,method='POST',host=dnsContainerObject[dnsServer]['props']['host'],action='updateDns').send()
            else:
                dnsServer = args.name
                dnsContainerObject = ContainerObject(dnsServer).create()
                pprint(dnsContainerObject)
                result = SendHTTPData(data=dnsContainerObject,method='POST',host=dnsContainerObject[dnsServer]['props']['host'],action='updateDns').send()
           # else:

        if containerObject[args.name].get('puppet'):
            if isinstance(containerObject[args.name]['puppet'],dict):
                for puppetServer in containerObject[args.name]['puppet'].keys():
                    puppetContainerObject = ContainerObject(puppetServer).create()
                    puppetContainerObject[puppetServer]['targetContainer']= containerObject
                    pprint(puppetContainerObject)
                    result = SendHTTPData(data=puppetContainerObject,method='POST',host=puppetContainerObject[puppetServer]['props']['host'],action='updatePuppet').send()


    if args.action == 'remove':
        ipAddressInfo = SendHTTPData(data=containerObject,method='POST',host=containerObject[args.name]['props']['host'],action=args.action).send()
        if containerObject[args.name].get('puppet'):
            if isinstance(containerObject[args.name]['puppet'],dict):
                for puppetServer in containerObject[args.name]['puppet'].keys():
                    puppetContainerObject = ContainerObject(puppetServer).create()
                    puppetContainerObject[puppetServer]['targetContainer']= containerObject
                    pprint(puppetContainerObject)
                    #result = SendHTTPData(data=puppetContainerObject,method='POST',host=puppetContainerObject[puppetServer]['props']['host'],action='syncPuppet').send()
     
            #print result
