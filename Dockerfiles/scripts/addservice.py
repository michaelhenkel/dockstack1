#!/usr/bin/python
import yaml
import json
import argparse

parser = argparse.ArgumentParser(description='updates hiera file')
parser.add_argument('--filename', metavar='f',
                   help='Hiera file')
parser.add_argument('--service', metavar='s', 
                   help='service to register')
parser.add_argument('--node', metavar='s', 
                   help='node to register')

args = parser.parse_args()
f = open(args.filename,'r')
yaml_file = f.read().strip()
service=args.service
node=args.node
yaml_object=yaml.load(yaml_file)
if service not in yaml_object['haproxy']['registered_services']:
  yaml_object['haproxy']['registered_services'][service]=[]

yaml_object['haproxy']['registered_services'][service].append(node)


outfile = file(args.filename,'w')
yaml.dump(yaml_object, outfile, default_flow_style=False)
print yaml.dump(yaml_object, default_flow_style=False)

f.close()
