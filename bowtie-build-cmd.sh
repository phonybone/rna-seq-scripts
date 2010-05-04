#!/bin/sh

org=human
size=31

root_dir=/proj/hoodlab/share/vcassen/
rnaseq_dir=$root_dir/rna-seq
bowtie_dir=$rnaseq_dir/bowtie
genomes_dir=/jdrf/data_var/solexa/genomes

org_dir=$genomes_dir/$org

# these two items have to be kept "in sync"
#color='_color'
#build_opts='-C'
color=

bowtie_build=bowtie-build
index_prefix=${org}_spliced_${size}${color}



# FIXME! edit this list if org != mouse


human_genome_files=${genomes_dir}/$org/fasta/chr10.fa,${genomes_dir}/$org/fasta/chr11.fa,${genomes_dir}/$org/fasta/chr12.fa,${genomes_dir}/$org/fasta/chr13.fa,${genomes_dir}/$org/fasta/chr14.fa,${genomes_dir}/$org/fasta/chr15.fa,${genomes_dir}/$org/fasta/chr16.fa,${genomes_dir}/$org/fasta/chr17.fa,${genomes_dir}/$org/fasta/chr18.fa,${genomes_dir}/$org/fasta/chr19.fa,${genomes_dir}/$org/fasta/chr20.fa,${genomes_dir}/$org/fasta/chr21.fa,${genomes_dir}/$org/fasta/chr22.fa,${genomes_dir}/$org/fasta/chr1.fa,${genomes_dir}/$org/fasta/chr2.fa,${genomes_dir}/$org/fasta/chr3.fa,${genomes_dir}/$org/fasta/chr4.fa,${genomes_dir}/$org/fasta/chr5.fa,${genomes_dir}/$org/fasta/chr6.fa,${genomes_dir}/$org/fasta/chr7.fa,${genomes_dir}/$org/fasta/chr8.fa,${genomes_dir}/$org/fasta/chr9.fa,${genomes_dir}/$org/fasta/chrX.fa,${genomes_dir}/$org/fasta/chrY.fa

mouse_genome_files=${genomes_dir}/$org/fasta/chr10.fa,${genomes_dir}/$org/fasta/chr11.fa,${genomes_dir}/$org/fasta/chr12.fa,${genomes_dir}/$org/fasta/chr13.fa,${genomes_dir}/$org/fasta/chr14.fa,${genomes_dir}/$org/fasta/chr15.fa,${genomes_dir}/$org/fasta/chr16.fa,${genomes_dir}/$org/fasta/chr17.fa,${genomes_dir}/$org/fasta/chr18.fa,${genomes_dir}/$org/fasta/chr19.fa,${genomes_dir}/$org/fasta/chr1.fa,${genomes_dir}/$org/fasta/chr2.fa,${genomes_dir}/$org/fasta/chr3.fa,${genomes_dir}/$org/fasta/chr4.fa,${genomes_dir}/$org/fasta/chr5.fa,${genomes_dir}/$org/fasta/chr6.fa,${genomes_dir}/$org/fasta/chr7.fa,${genomes_dir}/$org/fasta/chr8.fa,${genomes_dir}/$org/fasta/chr9.fa,${genomes_dir}/$org/fasta/chrX.fa,${genomes_dir}/$org/fasta/chrY.fa


org_splices="$org_dir/${org}_splice_jct.$size.fa"
bac_spikes="$genomes_dir/bacteria/081215_ERCC_reference.fasta"

cd $bowtie_dir

cmd="$bowtie_dir/$bowtie_build $build_opts ${human_genome_files},${org_splices},$bac_spikes $index_prefix"
echo $cmd

time nice $cmd

echo $index_prefix written to $bowtie_dir


