from superyaml import *
import yaml

sy=superyaml({'config_file': 'repeat.syml',
              })
sy.load()                               # should throw an exception


print "sy.config is %s" % yaml.dump(sy.config)
