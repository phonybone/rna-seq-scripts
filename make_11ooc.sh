#!/bin/sh

#$ -N make_ooc
#$ -m bea
#$ -M vcassen@systemsbiology.org
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/make_ooc.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/make_ooc.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

pwd
date

time /package/genome/bin/blat /jdrf/data_var/solexa/genomes/human/fasta/chr_all.fa /solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/s_1_export.10K.txt.fa  -makeOoc=11.ooc -ooc=11.ooc -out=pslx /solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/s_1_export.10K.txt.1.psl
