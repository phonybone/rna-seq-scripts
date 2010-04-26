#!/bin/sh

python=/hpc/bin/python
makerds=/proj/hoodlab/share/vcassen/rna-seq/commoncode/makerdsfromblat.py
label=sample_412_fcl_585
working_dir=/solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/10K
export_file=s_1_export.10K.txt
infile="$working_dir/$export_file.psl"
outrdsfile=$working_dir/rds/$export_file.rds
genedata=/jdrf/data_var/solexa/genomes/human/knownGene.txt
options="-forceRNA -index -cache 1000 -RNA $genedata -rawreadId"

echo $python $makerds $label $infile $outrdsfile $options
#$python $makerds $label $infile $outrdsfile $options

#python makerdsfromblat.py label infilename outrdsfile [-append] [-index] [propertyName::propertyValue] 
#[-rawreadID] [-forceRNA]  [-flag] [-strict minSpliceLen] [-spliceonly] [-verbose] [-cache numPages]

