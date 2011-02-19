import re
from yaml import load,dump
from superyaml import superyaml


h={'config_file':'/users/vcassen/software/starflow/Temp/rnaseq/rnaseq.yml.template',
   'globals_file': '/users/vcassen/software/starflow/Temp/rnaseq/globals.yml',
              }
sy=superyaml(h)
sy.load()
print "sy is\n%s" % dump(sy.config)


