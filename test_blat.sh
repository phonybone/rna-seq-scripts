#!/bin/sh

#$ -N test_blat
#$ -m bea
#$ -M vcassen@systemsbiology.org
#$ -o /proj/hoodlab/share/vcassen/rna-seq/scripts/test_blat.out
#$ -e /proj/hoodlab/share/vcassen/rna-seq/scripts/test_blat.err
#$ -P solexatrans
#$ -l h_rt=72:00:00

time /package/genome/bin/blat \
/jdrf/data_var/solexa/genomes/human/fasta/chr1.nib \
/solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/s_1_export.10K.txt.fa \
-ooc=/jdrf/data_var/solexa/genomes/human/fasta/11.ooc \
-out=pslx -fine -minScore=73 -fastMap -minIdentity=97\
/solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/s_1_export.txt.1.psl
