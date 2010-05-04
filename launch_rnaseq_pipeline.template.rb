"#!/bin/sh

#\$ -N #{label}
#\$ -m bea
#\$ -M #{email}
#\$ -o #{working_dir}/#{label}.out
#\$ -e #{working_dir}/#{label}.err
#\$ -P solexatrans
#\$ -l h_rt=72:00:00

# This is a templated (eval'd) ruby script that calls rnaseq_pipeline.rb

sh /proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/launch_#{label}.sh
"
