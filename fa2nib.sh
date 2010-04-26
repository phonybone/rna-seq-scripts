#!/bin/sh


faToNib=/package/genome/bin/faToNib
genomes=/jdrf/data_var/solexa/genomes


org=$1
case $org in
    human) n_genes=22;;
    mouse) n_genes=19;;
esac

if [ -z $n_genes ]; then
    echo usage: $0 \[human\|mouse]
    exit 1
fi

#for i in `seq 1 $n_genes` X Y; do
#    echo i is $i
#    $faToNib $genomes/$org/fasta/chr$i.fa $genomes/$org/fasta/chr$i.nib
#done
$faToNib $genomes/$org/fasta/rna.fa $genomes/$org/fasta/rna.nib
