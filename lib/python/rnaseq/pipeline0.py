#-*-python-*-
'''
This script writes a python script that implements an RNA-Seq pipeline using Starflow
provenance tracking.

Inputs: the location of a yaml-formatted config file with metadata describing the sample to
        be processed.  Grep 'required' (below) for the list of required fields (currently 7)

Outputs: Writes said python script in a directory defined by the 'export_dir' field in the input,
         appended with two levels of sub-directory.  The first is a sample-specific subdir (because
         more than one sample may occupy a directory) and the second is a time-stamp defined subdir
         (to distinguish different runs on the same sample).

'''

import sys
sys.path.append('/proj/hoodlab/share/vcassen/lib/python')
sys.path.append('/proj/hoodlab/share/vcassen/lib/python/rnaseq')
sys.path.append('/proj/hoodlab/share/vcassen/lib/python/starflow')
sys.path.append('/proj/hoodlab/share/vcassen/lib/python/starflow/starflow')

from Rnaseq.Pipeline import *
from Rnaseq.Sample import *
import yaml
import os.path
from evoque import *
from evoque.domain import Domain
import shutil
import tarfile

'''
Inputs:
- globals.yml: describes global variables (default: ./globals.yml)
- rnaseq.sample.yml: describes sample (sys.argv[1])
- pipeline.steps.syml: describes pipeline steps (default: globals.python_lib+'rnaseq/pipeline.steps.syml'

Todo:
Have to separate rnaseq.syml template into two bits: one that has rnaseq pipeline info, and one that
has specific sample info.  The pipeline template is non-variant for a particular pipeline.

'''
########################################################################


def main():
    # get args
    if len(sys.argv) < 2:
        die("usage: %s <rnaseq.yml>" % sys.argv[0])
    rnaseq_yml=sys.argv[1]

    # read global variables yaml:
    globals=load_globals()

    # create sample object:
    sample=RnaseqSample({'conf_file':rnaseq_yml}).load()

    # create pipeline object and mkdir working_dir:
    pipeline=RnaseqPipeline({'globals':globals,'steps_syml':globals['python_lib']+'/rnaseq/pipeline.steps.syml','sample':sample}) # fixme: pipeline.steps.syml should really be command-line param
    pipeline.load()
    working_dir=sample.working_dir()
    os.makedirs(working_dir)

    # copy and unzip starflow instance, write starflow config files:
    instantiate_starflow(pipeline,sample,globals)

    # copy rnaseq.yml to working_dir:
    shutil.copy(rnaseq_yml,working_dir)

    # write the rnaseq pipeline script:
    write_rnaseq_script(globals,pipeline,sample)

    # write the rnaseq's pipeline (starflow) script:
    starflow_script=write_starflow_script(pipeline,globals,sample)

    # write a qsub script calling the starflow script:
    write_qsub_script(sample,pipeline,globals,starflow_script)
    
    # execute starflow script: (I think...)
#    execfile(os.path.join(working_dir,'starflow/Temp',script_name))

    print "done"

########################################################################

def load_globals():
    f=open('globals.yml','r')
    globals=yaml.load(f)
    f.close
    return globals


# Write RNA-Seq script.  This script defines the steps needed in the rna-seq
# pipeline, which will be called by the starflow script (below).
def write_rnaseq_script(globals,pipeline,sample):
    domain=globals['domain']
    d=Domain(domain)
    t=d.get_template(globals['rnaseq_template'])

    # build up list of rnaseq.steps to be included in the final script:

    # augment globals hash with rnaseq vars:
    vars={'globals_file':'globals.yml',
          'rnaseq_steps':pipeline.as_python(),
          'steps_syml':os.path.join(globals['python_lib'],'pipeline.steps.syml'),     # hardcoded (for now?)
          'sample_yml':sample.conf_file,
          'timestamp':sample.timestamp(),
          }
    vars.update(globals)
    rnaseq_script=t.evoque(vars)

    # write script:
    os.mkdir(os.path.join(sample.working_dir(),'starflow','rnaseq'))
    fn=pipeline.script_filename('starflow/rnaseq','rnaseq','py')
    f=open(fn, 'w')
    f.write(rnaseq_script)
    f.close
    print "%s written" % fn
    return fn

    

# Write the starflow "entry" script.  This script calls the starflow command to
# resolve dependencies and create necessary files (ie, it "invokes" starflow).
def write_starflow_script(pipeline, globals, sample):
    domain=globals['domain']
    d=Domain(domain)
    t=d.get_template(globals['starflow_template'])

    # build the rest of the variables:
    vars={'working_dir':sample.working_dir(),
          'org':sample.org,
          }
    vars.update(globals)
    starflow_script=t.evoque(vars)
    
    # write script:
    fn=pipeline.script_filename('starflow/Temp','go','py')
    f=open(fn, 'w')
    f.write(starflow_script)
    f.close
    print "%s written" % fn
    return fn



# install a working version of starflow in the sample's working directory tree
# and write the config files appropriately.
def instantiate_starflow(pipeline,sample,globals):
    working_dir=sample.working_dir()
    shutil.copy(os.path.join(pipeline.globals['python_lib'],'starflow.minimal.tgz'),working_dir)

    tf=tarfile.open(os.path.join(working_dir,'starflow.minimal.tgz'))
    tf.extractall(path=working_dir)
    os.rename(os.path.join(working_dir,'starflow.minimal'),os.path.join(working_dir,'starflow'))
    os.unlink(os.path.join(working_dir,'starflow.minimal.tgz'))
                 
    # write starflow config files
    f=open(os.path.join(working_dir,'starflow/starflow/config','configure_automatic_updates.txt'),'w')
    f.write("^rnaseq.*\n")                   # all steps start like this
    f.close()

    f=open(os.path.join(working_dir,'starflow/starflow/config','configure_live_module_filters.txt'),'w')
    f.write("../rnaseq\n")                # or something (this works)
    f.close()

    # overwrite starflow/starflow/config/PerMachineSetup.py; be lazy and hard-code contents:
    bin_dir=globals['bin_dir']
    f=open(os.path.join(working_dir,'starflow/starflow/config/PerMachineSetup.py'),'w')
    f.write("PATH_TO_PYTHON='%s/python'\n" % bin_dir)
    f.write("DEFAULT_CALLMODE='DIRECT'\n")
    f.close()
    


def write_qsub_script(sample,pipeline,globals,starflow_script):
    # read generic template
    domain=globals['script_dir']
    d=Domain(domain)
    t=d.get_template(globals['qsub_template'])

    # eval template
    vars=pipeline.conf
    vars['label']=sample.label()
    vars['email']=sample.email
    vars['working_dir']=sample.working_dir()
    vars['cmd']="%s/python %s" % (globals['bin_dir'], starflow_script)
    
    template=t.evoque(vars)

    # write results
    filename=os.path.join(sample.working_dir(),'starflow','rnaseq','launch.qsub')
    f=open(filename,'w')
    f.write(template)
    f.close
    print "%s written" % filename
    return filename



########################################################################
# DEAD CODE BELOW
########################################################################


# write out the rnaseq steps, wrapped in a qsub script, and launch the script
# dead code
def write_simple_script(rnaseq,globals):
    job_script=write_job_script(rnaseq)
    qsub_script=write_qsub_script(rnaseq,globals,job_script)
    launch_qsub(qsub_script,globals)


# dead code
def write_job_script(pipeline):
    filename=os.path.join(sample.working_dir(),'rnaseq.py')
    f=open(filename,'w')
    for s in pipeline.steps:
        f.write(s.step_str())
    f.close()
    print "%s written" % filename
    return filename

def launch_qsub(qsub_script,globals):
    qsub_cmd="%s %s" % (globals['qsub_exe'],qsub_script)
    ssh_cmd="%s %s@%s '%s'" % (globals['ssh_cmd'],os.environ['USER'],globals['qsub_host'], qsub_cmd)
    print "%s (not really)" % ssh_cmd
#    sys.system(ssh_cmd)                     # will wait for password


def die(msg):
    print >> sys.stderr, msg
    sys.exit(1)

main()
