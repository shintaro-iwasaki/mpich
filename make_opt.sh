NJOBS=$1
DEVICE=$2
MODE=$3
if [ x"$MODE" = x ]; then
    echo "Usage: sh make_opt.sh NJOBS DEVICE MODE(=main all onlyopt)"
    exit 1
fi

if [ x"$MODE" != x"onlyopt" ]; then
  sh make.sh opt pth ${DEVICE} ${NJOBS} $(pwd)/install_${DEVICE}_pth
  sh make.sh opt pthvci ${DEVICE} ${NJOBS} $(pwd)/install_${DEVICE}_pthvci
  sh make.sh opt pthvciopt ${DEVICE} ${NJOBS} $(pwd)/install_${DEVICE}_pthvciopt
  sh make.sh opt abt ${DEVICE} ${NJOBS} $(pwd)/install_${DEVICE}_abt
fi
if [ x"$MODE" = x"all" -o x"$MODE" = x"onlyopt" ]; then
  for optnum in 1 2 3 4 5 6 7 8 9 0; do
    OPT_NUM=${optnum} sh make.sh opt abt ${DEVICE} ${NJOBS} $(pwd)/install_${DEVICE}_abt_${optnum}
  done
fi
