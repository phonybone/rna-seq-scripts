SGE_ROOT=/sge; export SGE_ROOT

ARCH=\`$SGE_ROOT/util/arch\`
DEFAULTMANPATH=\`$SGE_ROOT/util/arch -m\`
MANTYPE=\`$SGE_ROOT/util/arch -mt\`

SGE_CELL=aegir; export SGE_CELL
SGE_CLUSTER_NAME=aegir; export SGE_CLUSTER_NAME
unset SGE_QMASTER_PORT
unset SGE_EXECD_PORT

if [ \"$MANPATH\" = \"\" ]; then
   MANPATH=$DEFAULTMANPATH
fi
MANPATH=$SGE_ROOT/$MANTYPE:$MANPATH; export MANPATH

PATH=$SGE_ROOT/bin/$ARCH:$PATH; export PATH
# library path setting required only for architectures where RUNPATH is not supported
case $ARCH in
sol*|lx*|hp11-64)
   ;;
*)
   shlib_path_name=\`$SGE_ROOT/util/arch -lib\`
   old_value=\`eval echo '$'$shlib_path_name\`
   if [ x$old_value = x ]; then
      eval $shlib_path_name=$SGE_ROOT/lib/$ARCH
   else
      eval $shlib_path_name=$SGE_ROOT/lib/$ARCH:$old_value
   fi
   export $shlib_path_name
   unset shlib_path_name old_value
   ;;
esac
unset ARCH DEFAULTMANPATH MANTYPE

echo no_op.sh invoked on:
date

/sge/bin/lx24-amd64/qsub /proj/hoodlab/share/vcassen/rna-seq/scripts/no_op.qsub
exit 0
