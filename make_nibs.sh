#!/bin/sh

#$ -N make_nibs
#$ -m bea
#$ -M vcassen@systemsbiology.org
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/make_nibs.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/make_nibs.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

sh /proj/hoodlab/share/vcassen/rna-seq/scripts/fa2nib.sh human
sh /proj/hoodlab/share/vcassen/rna-seq/scripts/fa2nib.sh mouse
