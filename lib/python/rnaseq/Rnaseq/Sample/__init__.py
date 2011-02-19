# -*-python-*-
import sys
import yaml
import time
import os

from auto_attrs import *

class RnaseqSample(auto_attrs):
    attrs={'sample_id':None,
           'flow_cell_id':None,
           'pipeline_result_id':None,
           'export_dir':None,
           'export_file':None,
           'org':None,
           'email':None,
           'bowtie_index':None,
           'conf_file':None,
           '_working_dir':None,
           '_timestamp':None,
           }
    required=['sample_id','flow_cell_id','pipeline_result_id','export_dir','export_file','org','email','bowtie_index']

########################################################################

    def load(self):
        # read yml file:
        f=open(self.conf_file)
        conf=yaml.load(f)
        f.close()

        # check for missing values:
        missing=[]
        for k in self.required:
            try: self[k]=conf[k]
            except: missing.append(k)

        if len(missing) > 0:
            print("missing keys in %s: %s" % (sys.argv[1], ", ".join(missing)))
            sys.exit(1)

        return self

########################################################################

    def label(self):
        sample_id=str(self.sample_id)
        flow_cell_id=str(self.flow_cell_id)
        pipeline_result_id=str(self.pipeline_result_id)
        return 'post_pipeline_'+('_'.join([sample_id,flow_cell_id,pipeline_result_id]))

    def timestamp(self):
        if not self._timestamp:
            self._timestamp=time.strftime('%d%b%y.%H%M%S')
        return self._timestamp

    def working_dir(self):
        if not self._working_dir:
            ed=self.export_dir
            label=self.label()
            self._working_dir=os.path.join(ed,label,self.timestamp()) 
        return self._working_dir

    
                              
        

