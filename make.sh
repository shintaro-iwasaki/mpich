
OPT=$1
THREAD=$2
DEVICE=$3
NJOBS=$4
PREFIX=$5

if [ x"$DEVICE" = x ]; then
    echo "Usage: make.sh OPT THREAD DEVICE (NJOBS) (PREFIX)"
    echo "OPT = debug | opt | default | nompi"
    echo "THREAD = pth | pthvci | pthvciopt | abt"
    echo "DEVICE = ucx | ofi"
    echo "env: OPT_NUM = 0 1 2 3 4 5 6 7 8"
    exit 1
fi
if [ x"$NJOBS" = x ]; then
    NJOBS=1
fi
if [ x"$PREFIX" = x ]; then
    PREFIX="$(pwd)/install"
fi

if [ ! -f "configure" ]; then
    echo "## Run autogen.sh"
    date
    sh autogen.sh
fi

if [ ! -f "modules/ext_yaksa/install/lib/libyaksa.so" ]; then
    echo "## Compile Yaksa"
    date
    # Compile external Yaksa
    rm -rf modules/ext_yaksa
    cp -r modules/yaksa modules/ext_yaksa
    cd modules/ext_yaksa
    ./configure --prefix=$(pwd)/install
    make -j $NJOBS install
    cd ../../
fi

if  [ ! -f "argobots/install/lib/libabt.so" ]; then
    echo "## Compile Argobots"
    date
    if  [ ! -d "argobots" ]; then
        git clone git@github.com:shintaro-iwasaki/argobots-exp.git argobots
    fi
    cd argobots
    git checkout exp/opt
    sh autogen.sh
    ./configure --prefix=$(pwd)/install-fast --enable-perf-opt
    make -j $NJOBS install
    ./configure --prefix=$(pwd)/install --enable-fast=O0 --enable-debug=yes --enable-tls-model=initial-exec
    make -j $NJOBS install
    cd ../
fi

if  [ ! -f "argobots_unopt/install/lib/libabt.so" ]; then
    echo "## Compile Argobots"
    date
    if  [ ! -d "argobots" ]; then
        git clone https://github.com/pmodels/argobots.git argobots_unopt
    fi
    cd argobots_unopt
    sh autogen.sh
    ./configure --prefix=$(pwd)/install-fast --enable-perf-opt
    make -j $NJOBS install
    ./configure --prefix=$(pwd)/install --enable-fast=O0 --enable-debug=yes --enable-tls-model=initial-exec
    make -j $NJOBS install
    cd ../
fi

if [ x"$OPT" = x"nompi" ]; then
  exit 0
fi

cflags=""
config_opts="--with-ch4-shmmods=none --disable-fortran --with-yaksa=$(pwd)/modules/ext_yaksa/install --disable-numa"

if [ x"$OPT" = x"debug" ]; then
    config_opts="$config_opts --enable-fast=O0 --enable-g=dbg"
elif [ x"$OPT" = x"opt" ]; then
    config_opts="$config_opts --enable-fast=O3 --enable-g=none --enable-error-checking=no"
fi

optcflags=""
fastabtpath="$(pwd)/argobots_unopt/install-fast"
abtpath="$(pwd)/argobots_unopt/install"
if [ x"$OPT_NUM" != x"1" ]; then
    optcflags="${optcflags} -DVCIEXP_AOS_PROGRESS_COUNTS"
fi
if [ x"$OPT_NUM" != x"2" ]; then
    optcflags="${optcflags} -DVCIEXP_PADDING_MPIDI_UCX_CONTEXT_T"
fi
if [ x"$OPT_NUM" != x"3" ]; then
    optcflags="${optcflags} -DVCIEXP_NO_LOCK_SET_PROGRESS_VCI"
fi
if [ x"$OPT_NUM" != x"4" ]; then
    optcflags="${optcflags} -DVCIEXP_FAST_COUNT_ONE_REF_RELEASE"
fi
if [ x"$OPT_NUM" != x"5" ]; then
    optcflags="${optcflags} -DVCIEXP_FAST_UNSAFE_ADD_REF"
fi
if [ x"$OPT_NUM" != x"6" ]; then
    optcflags="${optcflags} -DVCIEXP_PADDING_OBJ_ALLOC_T"
fi
if [ x"$OPT_NUM" != x"7" ]; then
    optcflags="${optcflags} -ftls-model=initial-exec"
fi
if [ x"$OPT_NUM" != x"8" ]; then
    fastabtpath="$(pwd)/argobots/install-fast"
    abtpath="$(pwd)/argobots/install"
fi
if [ x"$OPT_NUM" != x"10" ]; then
    optcflags="${optcflags} -DVCIEXP_PER_STATE_PROGRESS_COUNTER"
fi
if [ x"$OPT_NUM" = x"9" ]; then
    optcflags=""
    fastabtpath="$(pwd)/argobots_unopt/install-fast"
    abtpath="$(pwd)/argobots_unopt/install"
fi

if [ x"$THREAD" = x"pthvci" ]; then
    cflags="${cflags} -DVCIEXP_LOCK_PTHREADS"
    config_opts="$config_opts --enable-thread-cs=per-vci --with-ch4-max-vcis=72"
elif [ x"$THREAD" = x"pthvciopt" ]; then
    cflags="${cflags} -DVCIEXP_LOCK_PTHREADS ${optcflags}"
    config_opts="$config_opts --enable-thread-cs=per-vci --with-ch4-max-vcis=72"
elif [ x"$THREAD" = x"abt" ]; then
    cflags="${cflags} -DVCIEXP_LOCK_ARGOBOTS ${optcflags}"
    config_opts="$config_opts --enable-thread-cs=per-vci --with-ch4-max-vcis=72 --with-thread-package=argobots"
    if [ x"$OPT" = x"opt" ]; then
        config_opts="$config_opts --with-argobots=$fastabtpath"
    else
        config_opts="$config_opts --with-argobots=$abtpath"
    fi
else
    cflags="${cflags}"
fi

if [ x"$DEVICE" = x"ucx" ]; then
    config_opts="$config_opts --with-device=ch4:ucx"
else
    config_opts="$config_opts --with-device=ch4:ofi --enable-psm2=yes --enable-psm=no --enable-sockets=no --enable-verbs=no"
fi

echo "## Configure MPICH"
echo "./configure --prefix=\"${PREFIX}\" ${config_opts} CFLAGS=\"$cflags\""
date
rm -rf Makefile
./configure --prefix="${PREFIX}" ${config_opts} CFLAGS="$cflags"

echo "## Compile MPICH"
date
make -j $NJOBS install
