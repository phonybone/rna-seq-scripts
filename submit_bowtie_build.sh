#!/bin/sh

#$ -N bowtie_build_h71
#$ -M vcassen@systemsbiology.org
#$ -m bea
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/bowtie_build_h71.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/bowtie_build_h71.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

/proj/hoodlab/share/vcassen/rna-seq/scripts/bowtie-build-cmd.sh
