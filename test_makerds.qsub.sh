#!/bin/sh

#$ -N test_makerds
#$ -m bea
#$ -M vcassen@systemsbiology.org
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/test_makerds.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/test_makerds.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

/bin/sh /proj/hoodlab/share/vcassen/rna-seq/scripts/test_makerds.sh
