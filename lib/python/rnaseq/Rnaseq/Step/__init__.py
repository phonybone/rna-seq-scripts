# -*-python-*-
import os
import traceback
from auto_attrs import *
import yaml
from evoque import *
from evoque.domain import Domain

class RnaseqStep(auto_attrs):

    attrs={'name':None,
           'interpreter':'',
           'exe':None,
           'args':[],
           'inputs':[],
           'outputs':[],
           'cmd_order':['interpreter', 'exe', 'args', 'inputs', 'outputs'],
           'rnaseq':None,
           'pipeline_var_name':'pipeline',
           }

    # return the step written as a python def statement:
    # called by RnaseqPipeline.as_python
    # where is self.rnaseq is set by RnaseqPipeline.load (when adding steps)
    def as_python(self):
        template_filename=self.rnaseq.globals['step_template']

        try: domain=self.rnaseq.globals['domain']
        except: domain=os.getcwd()
        t=Domain(domain).get_template(template_filename)

        # step.template needs: name, input, output, pipeline_var_name
        # fixme: we killed input_str(), etc, (not cmd_str(), tho)
        vars={'input':self.flatten_attr('inputs'),
              'output':self.flatten_attr('outputs'),
              'name':self.name,
              'pipeline_var_name':self.pipeline_var_name,
            }
        
        template=t.evoque(vars)
        return template


    # return a hash (dict) based on self where any self.attrs in self.cmd_order that are lists are flattened into strings:
    # fixme: add entry for 'cmd' so that we can include it while looping in as_python()?
    def flatten_attr(self,attr):
        if (type(self[attr]) == type([])):
            return ' '.join(self[attr])
        elif (self[attr]==None):
            return ''
        else:
            return self[attr]

        
    def cmd_str(self):
        cmd_list=map(lambda x: "%%(%s)s" % x, self.cmd_order)
        cmd_format=' '.join(cmd_list)
        d=self.flatten_cmd()                # doesn't actually change self
        cmd_str=cmd_format % d
        return cmd_str

    def flatten_cmd(self):
        d={}
        for attr in self.cmd_order:
            if (type(self[attr]) == type([])):
                d[attr]=' '.join(self[attr])
            elif (self[attr]==None):
                d[attr]=''
            else:
                d[attr]=self[attr]
        return d
    

    def run(self):
        cmd=self.cmd_str()
        print "%s cmd is %s" % (self.name, cmd)
        os.system(cmd)



# dead code
    dead_code='''
    def arg_str(self):
        # weird terenary operator; look it up if you don't believe me
        # argstr=" ".join(["%s%s" %(k,("" if v==None else "=%s"%v)) for k,v in self.args.items()])
        argstr=" ".join(self.args)
        return argstr

    def input_str(self):
        if self.inputs == None: return ''
        try:
            if len(self.inputs)==0: return ''
            return ' '.join(self.inputs)
        except:
            return self.inputs

    def output_str(self):
        if self.outputs == None: return ''
	try:
            if len(self.outputs)==0: return ''
            return " ".join(self.outputs)
        except:
            return self.outputs
    

    def cmd_str(self):
        # make format_dict by extracting attrs that exist and joining them, or defaulting to '':
        

        try:
            cmd=self.cmd_format % (self.interpreter, self.exe, self.arg_str(), self.input_str(), self.output_str())
            return cmd
        
        except KeyError as e:
            print "caught %s (%s)" % (e,type(e))
            print self

            sys.exit()
'''
