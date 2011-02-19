# -*-python-*-
import os.path
from auto_attrs import *
from Rnaseq.Step import *
from Rnaseq.Sample import *
from superyaml import superyaml
import os
import yaml

'''
This class is responsible for writing the python scripts that define an Rnaseq Pipeline
It uses:
- a conf file containing global values (globals.yml)
- an Rnaseq.Sample object
'''

class RnaseqPipeline(auto_attrs):
    attrs={'globals':{},
           'sample':None,
           'steps_syml':None,
           'steps':{},
           }


    def load(self):
        # read the pipeline's config file:
        self.read_conf()

        # set self.conf by evoque-ing the steps template:
        steps_basename=os.path.basename(self.steps_syml)
        self.globals.update(self.sample.attrs_dict())
        self.globals['working_dir']=self.sample.working_dir()
        self.globals['label']=self.sample.label()
        self.globals['org']=self.sample.org
        sy=superyaml({'config_file': steps_basename, 'globals': self.globals, 'domain':self.globals['domain']})
	sy.load()
        self.conf=sy.config

        # create and add steps (steps are specified by conf sections that have a 'name' key) (fixme)
        for k,v in self.conf.items():
            try:
                if v.has_key('name'):
                    v['rnaseq']=self
                    step=RnaseqStep(v)
                    # step.rnaseq=self
                    self.add_step(step)
            except AttributeError:
                pass
            except Exception:
                raise



    # fixme: why is this method needed?
    def read_conf(self):
        # get pipeline template
        # if steps_syml is an absolute pathname, over-write globals.domain with the basename:
        try:
            if self.steps_syml.startswith("/"):
                domain=os.path.dirname(self.steps_syml)
            else:
                domain=self.globals['domain']
        except:
            print "Can't set domain for template system; check globals.yml or command-line args"
            sys.exit(1)

########################################################################

    def add_step(self,step):
        self.steps[step.name]=step

    # called by pipeline0.py
    def as_python(self):
        p=""
        for s in self.steps.values():
            p+=s.as_python()+"\n"
        return p

        
########################################################################

    def script_filename(self,subdir,basename,suffix):
        fn=os.path.join(self.sample.working_dir(), subdir, basename+'.'+suffix)
        return fn
        

########################################################################

    def run(self):
        for step in steps.values(): step.run


#     def get_conf(self,val):
#         str="self.conf%s"
#         ret=eval(str)
#         return ret


