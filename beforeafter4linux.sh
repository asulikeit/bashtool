#!/bin/bash
export LANG=C
typeset -u OPTION
ARGUMENT=$0
PATH=${PATH}:/sbin:/usr/sbin:/usr/bin:/bin
DD=`date "+%y%m%d"`
DT=`date "+%Y%m%d%H%M"`
acct=`tput bold`
blk=`tput blink`
retn=`tput sgr0`
ZERO=0
###############((Default value))
DIR=/home/daniel/nwadmin/CHECKLIST
LOGDIR=${DIR}/LOG
FILEDIR=${DIR}/FILE
LOGFILE=${LOGDIR}/chk_log
PERMFILE=${FILEDIR}/perminfo
[ -d ${LOGDIR} ] || mkdir -p ${LOGDIR}
[ -d ${FILEDIR} ] || mkdir -p ${FILEDIR}
RESULT=${LOGDIR}/result.txt
TMPLOG=${LOGDIR}/tempo.txt
TMPTXT=${LOGDIR}/tempo2.txt
DIFLOG1=${LOGDIR}/diff_log1.tmp
DIFLOG2=${LOGDIR}/diff_log2.tmp
STEP=0
###############((Return value))
Retn_OK=${ZERO}
Retn_check=50
Retn_quit=51
Retn_err=52
Retn_nobefore=53
Retn_nooption=54
Retn_norecord=55
Retn_nolinux=56
Retn_n2dcheck=100
retnval=${Retn_OK}
N2DCHECK=${Retn_n2dcheck}
###############((File & Process))
PROCLIST="crond inetd opsware syslogd ntpd"
FILELIST="/etc/fstab /etc/modprobe.conf /etc/sysconfig/hwconf /etc/selinux/config /etc/sysctl.conf"
PERMLIST="/etc/hosts /etc/passwd /etc/group /etc/shadow"
###############((Start))
func_proc(){
    filename=$1
    i=0
    cp /dev/null ${filename}
    #unset array
    #set -A array ${PROCLIST}
    #while [ $i -lt ${#array[@]} ];do
    for proc in ${PROCLIST}; do
        ps -ef | awk '{print substr($0,49)}' 2>/dev/null \
        | grep ${proc} | grep -v grep >> ${filename}
        (( i+=1 ))
    done
    return $i
}

func_file(){
    filename=$1
    i=0
    j=0
    cp /dev/null ${filename}
    #unset array
    #set -A array ${PERMLIST}
    #while [ $i -lt ${#array[@]} ]; do
    for perm in ${PERMLIST}; do
        if [ -f ${perm} ]; then
            ls -l ${perm} | awk '{print $9"\t"$1}' >> ${filename}
            (( j+=1 ))
        else
            printf "\tThere isn't ${perm}"
        fi
        (( i+=1 ))
    done
    return $j
}

FUNC_checkfile(){
    CONTENT=$1
    TYPE=$2
    i=0
    j=0
    cp /dev/null ${RESULT}
    cp /dev/null ${TMPTXT}

    (( STEP+=1 ))
    printf "%3s %s $s" "${STEP}." ${CONTENT} ${ACTIVITY}
    printf "......."
    echo ${CONTENT} | awk '{printf("%-7s %s\n", "Type", $0)}' >> ${LOG}
    #unset array
    #set -A array ${FILELIST}
    if [ ${BEFORE} = "BEFORE" ]; then
        #while [ $i -lt ${#array[@]} ]; do
        for file in ${FILELIST}; do
            Source_File=${file}
            Target_File=${file##*/}_OK_${DD}
            if [ -f ${Source_File} ]; then
                printf "${Source_File}:${Target_File}" >> ${RESULT}
                egrep -v "^$|^#|^\*" ${Source_File} > ${FILEDIR}/${Target_File}
                (( j+=1 ))
            else
                printf "\tThere isn't ${Source_File}." >> ${TMPTXT}
            fi
            (( i+=1 ))
        done
        while read BOA; do
            echo ${BOA} | awk -v type=${TYPE} '{printf("%-7s %s\n", type, $0)}' >> ${LOG}
        done < ${RESULT}
        echo >> ${LOG}
        echo "Done[${j}]."
        cat ${TMPTXT}
    else
        for BOA in $(grep ^${TYPE} ${LASTLOG} | awk '{print $2}'); do
            echo ${BOA} | awk -v type=${TYPE} '{printf("%-7s %s ..", type, $0)}' >> ${LOG}
            Source_File=$(echo ${BOA} | cut -d: -f1)
            Target_File=$(echo ${BOA} | cut -d: -f2 | awk -v dir=${FILEDIR} '{print dir"/"$0}')
            if [ -f ${Source_File} ];then
                if [ -f ${Target_File} ];then
                    printf "\t${Source_File} & ${Target_File} are compared.." >> ${RESULT}
                    (( i+=1 ))
                    egrep -v "^$|^#|^\*" ${Source_File} > ${DIFLOG1}
                    egrep -v "^$|^#|^\*" ${Target_File} > ${DIFLOG2}
                    diff ${DIFLOG1} ${DIFLOG2} > ${TMPTXT}
                    if [ $? -eq ${Retn_OK} ];then
                        echo "OK" >> ${RESULT}
                    else
                        echo "Fail" >> ${RESULT}
                        (( j+=1 ))
                        grep -v ^[0-9\-] ${TMPTXT} | sed "s/^</after\) /g" | sed "s/^>/befor\) /g" \
                         | awk -v file=${Source_File} '{print "\t >"file": ("$0}' >> ${RESULT}
                    fi
                else
                    printf "\tIt's failed to compare ${Source_File} & ${Target_File}" >> ${RESULT}
                fi
            else
                printf "\t${Source_File} is Deleted.." >> ${RESULT}
                (( j+=1 ))
            fi
        done
        if [ ${j} -eq ${ZERO} ]; then
            echo "OK[$i]."
        else
            (( N2DCHECK+=1 ))
            echo "${acct} need to check${retn}[$j]."
            cat ${RESULT}
        fi
        while read BOA; do
            echo ${BOA} | awk -v type=${TYPE} '{printf("%-7s %s\n", type, $0)}' >> ${LOG}
        done < ${RESULT}
    fi
    return ${Retn_OK}
}

FUNC_checkrst(){
    CONTENT=$1
    TYPE=$2
    CMDRETURN=$3
    cat ${TMPLOG} | grep -v ^$ | sort > ${RESULT}

    (( STEP+=1 ))
    printf "%3s %s $s" "${STEP}." ${CONTENT} ${ACTIVITY}
    printf "......."
    echo ${CONTENT} | awk '{printf("%-7s %s\n", "Type", $0)}' >> ${LOG}
    while read BOA; do
        echo ${BOA} | awk -v type=${TYPE} '{printf("%-7s %s\n", type, $0)}' >> ${LOG}
    done < ${RESULT}
    echo >> ${LOG}
    sleep 1

    if [ ${BEFORE} = "AFTER" ]; then
        grep ^${TYPE} ${LOG} > ${DIFLOG1}
        grep ^${TYPE} ${LASTLOG} > ${DIFLOG2}
        diff ${DIFLOG1} ${DIFLOG2} > ${TMPLOG}
        if [ $(cat ${TMPLOG} | wc -l) -lt 1 ];then
            echo "OK[${CMDRETURN}]."
        else
            (( N2DCHECK+=1 ))
            echo "${acct} need to check${retn}[${CMDRETURN}]."
            grep -v ^[0-9\-] ${TMPLOG} | sed "s/^</\(after\) /g" \
             | sed "s/^>/\(befor\) /g" | awk '{print "\t"$0}'
        fi
    else
        echo "Done[${CMDRETURN}]."
    fi
    return ${CMDRETURN}
}

FUNC_command(){
########
    hostname > ${TMPLOG}
    FUNC_checkrst "Hostname" "HOST" $?
########
    egrep "^process|cpu MHz" /proc/cpuinfo > test.out
    while read BOA; do
        if [ $(echo ${BOA} | cut -c-4) = "proc" ]; then
            printf "${BOA}\t"
        else
            printf ${BOA}
        fi
    done < test.out > ${TMPLOG}
    FUNC_checkrst "CPU_information" "CPU" $?
########
    grep ^MemTotal /proc/meminfo > ${TMPLOG}
    FUNC_checkrst "Memory_information" "MEM" $?
########
    swapon -s | grep -v Filename | awk '{print $1,$2,$3}' > ${TMPLOG}
    FUNC_checkrst "SWAP_information" "SWAP" $?
########
    ifconfig | egrep "^eth" > ${TMPLOG}
    FUNC_checkrst "NIC_status" "NIC" $?
########
    for i in $(ifconfig|grep "^eth" | awk '{print $1}'); do
        ethtool $i > test.out
        printf "${i} \t["
        printf "$(grep Speed: test.out), "
        printf "$(grep Duplex: test.out), "
        printf "$(grep Auto-negotiation: test.out), "
        printf "$(grep 'Link detected:' test.out)]"
    done > ${TMPLOG}
    FUNC_checkrst "Network_status" "NWS" $?
########
    BONDIR=/proc/net/bonding
    if [ -f ${BONDIR}/bond*[0-9] ]; then
        for i in $(ls ${BONDIR}/bond*[0-9]); do
            egrep "Mode|Slave" $i | awk -v bonvar=$i '{print bonvar" : "$0}'
        done > ${TMPLOG}
        FUNC_checkrst "NIC_Bonding" "BOND" $?
    fi
########
    route -n | egrep -v "^Kernel|^Dest" > ${TMPLOG}
    FUNC_checkrst "Routing_table" "ROUT" $?
########
    ntpq -p | egrep -v "delay|^=" | awk '{print $1,$2}' > ${TMPLOG}
    FUNC_checkrst "NTP" "NTP" $?
########
    func_proc ${TMPLOG}
    FUNC_checkrst "Process" "PROC" $?
########
    func_file ${TMPLOG}
    FUNC_checkrst "File_permission" "FPERM" $?
########
    FUNC_checkfile "Important_file" "FCONT"
########
    grep -v ^major /proc/partitions > ${TMPLOG}
    FUNC_checkrst "DISK_Partion" "FDSK" $?
########
    df -TP | grep -v "^Filesystem" | awk '{print $1,$2,$7}' > ${TMPLOG}
    FUNC_checkrst "Filesystem" "FS" $?
########
    mount > ${TMPLOG}
    FUNC_checkrst "Mount_FS" "MNT" $?
########
    cat /proc/mdstat > ${TMPLOG}
    FUNC_checkrst "Software_RAID" "SRAID" $?
########
    vgdisplay 2>/dev/null > ${TMPLOG}
    FUNC_checkrst "Volume_group" "VOLG" $?
########
    lvdisplay 2>/dev/null > ${TMPLOG}
    FUNC_checkrst "Logical_volume" "LVOL" $?
########
    /usr/sbin/sestatus > ${TMPLOG}
    FUNC_checkrst "SEstatus" "SES" $?
########
    #/sbin/chkconfig --list > ${TMPLOG}
    #FUNC_checkrst "Service" "SVC" $?
########
    #/sbin/iptables -L > ${TMPLOG}
    #FUNC_checkrst "IP_Table" "IPT" $?
########
    sysctl -a > ${TMPLOG}
    FUNC_checkrst "Kernel_parameter" "KERP" $?
########
    return ${Retn_OK}
}

main(){
    case $1 in
        "BEFORE")
            BEFORE="BEFORE"
            ACTIVITY="check"
        ;;
        "AFTER")
            if [ ! -f ${LOGFILE}*BEFORE* ]; then
                printf "\n You shoud execute with before option first.\n"
                return ${Retn_nobefore}
            fi
            LASTLOG=$(ls -rlt ${LOGDIR}/*BEFORE* | tail -1 | awk '{print $NF}')
            BEFORE="AFTER"
            ACTIVITY="check_result"
        ;;
        "CHECK")
            main "BEFORE"
            main "VIEW"
            return $?
        ;;
        "VIEW")
            ls ${LOGFILE}* &>/dev/null
            if [ $? -ne ${Retn_OK} ]; then
                printf "\n There are not any log files.\n"
                return ${Retn_norecord}
            fi
            cat $(ls -rlt ${LOGFILE}* | tail -1 | awk '{print $NF}')
            return ${Retn_OK}
        ;;
        *)
            printf "[Usage] ${ARGUMENT##*/} before|after|check|view\n"
            return ${Retn_nooption}
        ;;
    esac
    LOG=${LOGFILE}_${BEFORE}_${DT}.$(hostname)
    VERSION=$(uname -r | awk -F. '{print $3}')

    FUNC_command
#####   FUNC_checkfile

    printf "==========================\n"
    [ ${N2DCHECK} -eq ${Retn_n2dcheck} ] || retnval=${N2DCHECK}
    return ${retnval}
}

if [ $# -lt 1 ];then
    OPTION="yuna1004"
else
    OPTION="$1"
fi

printf "\n======Checklist for LINUX by LKH=====\n"
if [ $(uname -s) != "Linux" ]; then
    echo "This script is only for Linux OS"
    exit ${Retn_nolinux}
fi
main ${OPTION}
exit $?
