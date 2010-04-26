#!/bin/sh

#$ -N test_blatnib
#$ -m bea
#$ -M vcassen@systemsbiology.org
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/test_blatnib.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/test_blatnib.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

/hpc/bin/ruby /proj/hoodlab/share/vcassen/rna-seq/scripts/blatnib.rb
