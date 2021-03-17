DEVICE=$1
full=$2
if [ x"$full" = x ]; then
  echo "Usage: sh run.sh DEVICE FULL(=0|1)"
  exit 1
fi

MPICH_PTH_PATH=$(pwd)/../install_${DEVICE}_pth
MPICH_PTHVCI_PATH=$(pwd)/../install_${DEVICE}_pthvci
MPICH_PTHVCIOPT_PATH=$(pwd)/../install_${DEVICE}_pthvciopt
MPICH_ABT_PATH=$(pwd)/../install_${DEVICE}_abt
TIMEOUT="timeout -s 9 600"
BIND="numactl -m 0 --cpunodebind 0"
export NUM_REPEATS=5
export HFI_NO_CPUAFFINITY=1
date

${MPICH_PTH_PATH}/bin/mpiexec -n 2 hostname

winsize_list="32 64 128"
for winsize in ${winsize_list}; do
    for repeat in $(seq 20); do
        echo "# repeat $repeat / 20"
        num_messages="500000"
        num_entities_list="1 2 4 6 8 12 16 32"
        msgsize=1
        for num_entities in ${num_entities_list}; do
            num_messages_sp=$num_messages
            if [ x"$num_entities" != x"1" ]; then
                num_messages_sp="5000"
            fi

            date
            echo "#### proc $num_messages $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n $(($num_entities * 2)) ${BIND} ./${DEVICE}_pth.out 0 $num_entities 1 $num_messages $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n $(($num_entities * 2)) ${BIND} ./${DEVICE}_pth.out 0 $num_entities 1 $num_messages $winsize $msgsize

            date
            echo "#### pth_novci_1comm $num_messages_sp $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pth.out 1 $num_entities 1 $num_messages_sp $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pth.out 1 $num_entities 1 $num_messages_sp $winsize $msgsize

            if [ x"$full" != x0 ]; then
                date
                echo "#### pth_novci_Ncomm $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pth.out 1 $num_entities $num_entities $num_messages_sp $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} ${TIMEOUT} ${MPICH_PTH_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pth.out 1 $num_entities $num_entities $num_messages_sp $winsize $msgsize

                date
                echo "#### pth_vci_1comm $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities 1 $num_messages_sp $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities 1 $num_messages_sp $winsize $msgsize

                date
                echo "#### pth_vci_Ncomm $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities $num_entities $num_messages $winsize $msgsize

                date
                echo "#### pth_vci_Ncomm_nolock_1comm $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=1 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=1 ${TIMEOUT} ${MPICH_PTHVCI_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvci.out 1 $num_entities $num_entities $num_messages $winsize $msgsize
            fi

            date
            echo "#### pth_vciopt_Ncomm $num_messages $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCIOPT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvciopt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=0 ${TIMEOUT} ${MPICH_PTHVCIOPT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvciopt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize

            date
            echo "#### pth_vciopt_Ncomm_nolock $num_messages $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=1 ${TIMEOUT} ${MPICH_PTHVCIOPT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvciopt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) NOLOCK=1 ${TIMEOUT} ${MPICH_PTHVCIOPT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_pthvciopt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize

            date
            echo "#### abt_vci_1comm_Nes $num_messages $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=$num_entities MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities 1 $num_messages $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=$num_entities MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities 1 $num_messages $winsize $msgsize

            if [ x"$full" != x0 ]; then
                date
                echo "#### abt_vci_1comm_1es $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=1 MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities 1 $num_messages $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=1 MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities 1 $num_messages $winsize $msgsize

                date
                echo "#### abt_vci_Ncomm_1es $num_messages $num_entities $winsize"
                echo "NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=1 MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
                NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=1 MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize
            fi

            date
            echo "#### abt_vci_Ncomm_Nes $num_messages $num_entities $winsize"
            echo "NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=$num_entities MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize"
            NUM_REPEATS=${NUM_REPEATS} ABT_MEM_LP_ALLOC=mmap_rp ABT_NUM_XSTREAMS=$num_entities MPIR_CVAR_CH4_NUM_VCIS=$(($num_entities + 2)) ${TIMEOUT} ${MPICH_ABT_PATH}/bin/mpiexec -n 2 ${BIND} ./${DEVICE}_abt.out 1 $num_entities $num_entities $num_messages $winsize $msgsize
        done
    done
done
echo "completed!"

