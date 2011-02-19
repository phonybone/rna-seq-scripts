from superyaml import *
import yaml

sy=superyaml({'config_file': 'cyclic.yml',
              })
sy.load()                               # should throw an exception


print "sy is %s" % yaml.dump(sy)



