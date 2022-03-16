#!/bin/bash 

## 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
END='\033[0m'
## 定义可执行文件路径
GOFLOW="$(dirname `readlink -f $0`)/goflow"  # goflow脚本路径（https://github.com/netsampler/goflow2）
JQ="$(dirname `readlink -f $0`)/gojq" # gojq脚本路径（https://github.com/itchyny/gojq）
## 检查是否为root用户
[ $(id -u) != "0" ] && { echo -e "${RED}[Error] 你必须使用root执行该脚本${END}"; exit 1; }
## 异常退出检测
trap 'StopThis 2>/dev/null && exit 0' 2 15
## 检测系统
if [ -n "$(grep 'Aliyun Linux release' /etc/issue)" -o -e /etc/redhat-release ];then
    OS=CentOS
    [ -n "$(grep ' 7\.' /etc/redhat-release)" ] && CentOS_RHEL_version=7
    [ -n "$(grep ' 6\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release6 15' /etc/issue)" ] && CentOS_RHEL_version=6
    [ -n "$(grep ' 5\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release5' /etc/issue)" ] && CentOS_RHEL_version=5
elif [ -n "$(grep 'Amazon Linux AMI release' /etc/issue)" -o -e /etc/system-release ];then
    OS=CentOS
    CentOS_RHEL_version=6
elif [ -n "$(grep bian /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Debian' ];then
    OS=Debian
    [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
    Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep Deepin /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Deepin' ];then
    OS=Debian
    [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
    Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep Ubuntu /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Ubuntu' -o -n "$(grep 'Linux Mint' /etc/issue)" ];then
    OS=Ubuntu
    [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
    Ubuntu_version=$(lsb_release -sr | awk -F. '{print $1}')
    [ -n "$(grep 'Linux Mint 18' /etc/issue)" ] && Ubuntu_version=16
elif [ ! -z "$(grep 'Arch Linux' /etc/issue)" ];then
    OS=Arch
else
    echo -e "${RED}[ERROR] 不受支持的操作系统！${END}"
    kill -9 $$
fi
## 检测screen
if command -v screen >/dev/null 2>&1;then
    echo -e "${YELLOW}[WARNING]${END} ${GREEN}screen is installed, skip${END}"
else
    echo -e "${YELLOW}[WARNING]${END} ${YELLOW}screen is not installed, start to install${END}"
    if [[ "$OS" == 'CentOS' ]];then
        yum install -y screen
    elif [[ "$OS" == 'Debian' ]];then
        apt-get -y update
        apt-get -y install screen
    elif [[ "$OS" == 'Ubuntu' ]];then
        apt-get -y update
        apt-get -y install screen
    elif [[ "$OS" == 'Arch' ]];then
        pacman -Sy screen
    fi
fi
## 定义变量
masks[0]="0.0.0.0"
masks[1]="128.0.0.0"
masks[2]="192.0.0.0"
masks[3]="224.0.0.0"
masks[4]="240.0.0.0"
masks[5]="248.0.0.0"
masks[6]="252.0.0.0"
masks[7]="254.0.0.0"
masks[8]="255.0.0.0"
masks[9]="255.128.0.0"
masks[10]="255.192.0.0"
masks[11]="255.224.0.0"
masks[12]="255.240.0.0"
masks[13]="255.248.0.0"
masks[14]="255.252.0.0"
masks[15]="255.254.0.0"
masks[16]="255.255.0.0"
masks[17]="255.255.128.0"
masks[18]="255.255.192.0"
masks[19]="255.255.224.0"
masks[20]="255.255.240.0"
masks[21]="255.255.248.0"
masks[22]="255.255.252.0"
masks[23]="255.255.254.0"
masks[24]="255.255.255.0"
masks[25]="255.255.255.128"
masks[26]="255.255.255.192"
masks[27]="255.255.255.224"
masks[28]="255.255.255.240"
masks[29]="255.255.255.248"
masks[30]="255.255.255.252"
masks[31]="255.255.255.254"
masks[32]="255.255.255.255"
b1="256"
b2="$((256 * b1))"
b3="$((256 * b2))"
## 检测ip是否为同一个网段
function check_ip(){
    local sip=$(echo ${1} | sed 's/\"//g')
    local ips=${2}
    local subnet=${ips%%/*}
    local bits=${ips##*/}
    local mask=${masks[$bits]}
    local ipFIELD1=$(echo "$sip" |cut -d. -f1)
    local ipFIELD2=$(echo "$sip" |cut -d. -f2)
    local ipFIELD3=$(echo "$sip" |cut -d. -f3)
    local ipFIELD4=$(echo "$sip" |cut -d. -f4)      
    local netmaskFIELD1=$(echo "$mask" |cut -d. -f1)
    local netmaskFIELD2=$(echo "$mask" |cut -d. -f2)
    local netmaskFIELD3=$(echo "$mask" |cut -d. -f3)
    local netmaskFIELD4=$(echo "$mask" |cut -d. -f4)
    local subsip="$[$(echo "$sip" |cut -d. -f1)&$netmaskFIELD1].$[$(echo "$sip" |cut -d. -f2)&$netmaskFIELD2].$[$(echo "$sip" |cut -d. -f3)&$netmaskFIELD3].$[$(echo "$sip" |cut -d. -f4)&$netmaskFIELD4]"
    local subaddr="$[$(echo "$subnet" |cut -d. -f1)&$netmaskFIELD1].$[$(echo "$subnet" |cut -d. -f2)&$netmaskFIELD2].$[$(echo "$subnet" |cut -d. -f3)&$netmaskFIELD3].$[$(echo "$subnet" |cut -d. -f4)&$netmaskFIELD4]"
    if [[ ${subsip} == ${subaddr} ]];then
        isSub="yes"
    fi
}
## 检测是否为偶数
function check_even(){
    local num=$(echo ${1} | sed 's/\"//g')
    if [[ $((num%2)) -eq 0 ]];then
        return 0
    else
        return 1
    fi
}
## 根据ttl判断是否为nat主机，由于ttl经过nat后会减1
function check_ttl(){
    local sflowfile=${1}
    local line
    local IFS=","
    local x
    while read line 
    do
        unset SrcAddr
        unset IPTTL
        unset SrcMac
        unset isSub
        SrcAddr=$(echo "${line}" | ${JQ} .SrcAddr)
        IPTTL=$(echo "${line}" | ${JQ} .IPTTL)
        SrcMac=$(echo "${line}" | ${JQ} .SrcMac)
        if [[ -z ${SrcAddr} ]];then
            continue
        fi
        if [[ -z ${IPTTL} ]];then
            continue
        fi
        if [[ -z ${opt} ]]; then
            check_ip ${SrcAddr} 192.168.0.0/16
            check_ip ${SrcAddr} 172.16.0.0/16
            check_ip ${SrcAddr} 10.0.0.0/8
        else
            for x in ${opt}
            do
                check_ip ${SrcAddr} ${x}
            done
        fi
        if [[ ${isSub} == "yes" ]]; then
            check_even ${IPTTL}
            if [[ $? != 0 ]]; then
                echo "${SrcAddr} ${SrcMac}" >> /tmp/check_nat.tmp
                echo "${SrcAddr} ${SrcMac} ${IPTTL}" >> /tmp/check_nat.tmp2
            fi
        fi
    done < `echo ${sflowfile}`
}
## 放通防火墙
function allow_fw(){
    local protocol=${1}
    local port=${2}
    if command -v iptables >/dev/null 2>&1;then
        systemctl status iptables >/dev/null 2>&1
        if [[ $? == 0 ]];then
            echo -e "${BLUE}[INFO]${END} ${GREEN}自动允许${END} ${port}/${protocol} ${GREEN}端口${END}"
            echo -e "\033[32m[+]\033[0m iptables -A INPUT -p ${protocol} --dport ${port} -j ACCEPT"
            iptables -A INPUT -p ${protocol} --dport ${port} -j ACCEPT >/dev/null 2>&1
            iptables_enable="yes"
        fi
    fi
    if command -v firewall-cmd >/dev/null 2>&1;then
        systemctl status firewalld >/dev/null 2>&1
        if [[ $? == 0 ]];then
            if [[ "${iptables_enable}" != "yes" ]]; then
                echo -e "${BLUE}[INFO]${END} ${GREEN}自动允许${END} ${port}/${protocol} ${GREEN}端口${END}"
            fi
            echo -e "\033[32m[+]\033[0m firewall-cmd --zone=public --add-port=${port}/${protocol} --permanent"
            firewall-cmd --zone=public --add-port=${port}/${protocol} --permanent >/dev/null 2>&1
            firewall_enable="yes"
        fi
    fi
    if command -v ufw >/dev/null 2>&1;then
        systemctl status ufw >/dev/null 2>&1
        if [[ $? == 0 ]];then
            if [[ "${iptables_enable}" != "yes" || "${firewall_enable}" != "yes" ]]; then
                echo -e "${BLUE}[INFO]${END} ${GREEN}自动允许${END} ${port}/${protocol} ${GREEN}端口${END}"
            fi
            echo -e "\033[32m[+]\033[0m ufw allow ${port}/${protocol}"
            ufw allow ${port}/${protocol} >/dev/null 2>&1
            ufw_enable="yes"
        fi
    fi
}
## 关闭防火墙
function deny_fw(){
    local protocol=${1}
    local port=${2}
    if [[ "${ufw_enable}" == "yes" || "${firewall_enable}" == "yes" || "${iptables_enable}" == "yes" ]]; then
        echo -e "${BLUE}[INFO]${END} ${RED}自动关闭${END} ${port}/${protocol} ${RED}端口${END}"
    if [[ ${ufw_enable} == yes ]]; then
        echo -e "\033[32m[+]\033[0m ufw delete allow ${port}/${protocol}"
        ufw delete allow ${port}/${protocol} >/dev/null 2>&1
    fi
    if [[ ${firewall_enable} == yes ]]; then
        echo -e "\033[32m[+]\033[0m firewall-cmd --zone=public --remove-port=${port}/${protocol}"
        firewall-cmd --zone=public --remove-port=${port}/${protocol} >/dev/null 2>&1
    fi
    if [[ ${iptables_enable} == yes ]]; then
        echo -e "\033[32m[+]\033[0m iptables -D INPUT -p ${protocol} --dport ${port} -j ACCEPT"
        iptables -D INPUT -p ${protocol} --dport ${port} -j ACCEPT >/dev/null 2>&1
    fi
}
## 停止函数
function StopThis(){
    echo -e "${YELLOW}[WARNING]${END} ${YELLOW}操作被中断，开始进行清理工作！${END}"
    if [[ ! -z $(screen -ls | grep goflow2) ]]; then
        screen -S goflow2 -X quit
        killall goflow
    fi
    rm -f /tmp/check_nat.tmp
    rm -f /tmp/goflow2.log
    rm -f /tmp/check_nat.tmp1 /tmp/check_nat.tmp2
    deny_fw "udp" "6344"
    echo -e "${YELLOW}[WARNING]${END} ${YELLOW}退出${END}"
    exit 0
}
## 处理参数
function parse_opt_equal_sign() {
    if [[ "$1" == *=* ]]; then
        echo ${1#*=}
        return 1 
     else
        echo "$2"
        return 0
    fi
}
## 处理传参
opt="192.168.0.0/16,172.20.0.0/16,172.16.0.0/16,10.0.0.0/8"
num="5"
i="1"
wait_time="10"
if [[ -f /tmp/check_nat.tmp ]]; then
    rm -f /tmp/check_nat.tmp
fi
if [[ -f /tmp/check_nat.tmp1 ]]; then
    rm -f /tmp/check_nat.tmp1 /tmp/check_nat.tmp2
fi
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|-f=*)
            opt="$(parse_opt_equal_sign "$1" "$2")"
            [[ $? -eq 0 ]] && shift
            ;;
        -n|-n=*)
            num="$(parse_opt_equal_sign "$1" "$2")"
            [[ $? -eq 0 ]] && shift
            ;;
        -t|-t=*)
            wait_time="$(parse_opt_equal_sign "$1" "$2")"
            [[ $? -eq 0 ]] && shift
            ;;
    esac
    shift
done
allow_fw "udp" "6344"
while :;do
    unset isSub
    if [[ -f /tmp/goflow2.log ]]; then
        rm -f /tmp/goflow2.log
    fi
    screen -dmS goflow2 ${GOFLOW} -metrics.addr ":6344" -transport.file /tmp/goflow2.log
    if [[ ${isRunning} != "yes" ]]; then
        echo -e "${BLUE}[INFO]${END} ${GREEN}开始采集数据！${END}"
        echo -e "${BLUE}[INFO]${END} ${GREEN}循环圈数: ${num}${END}"
    fi
    sleep ${wait_time}s
    screen -S goflow2 -X quit
    if [[ `ps -ef | grep goflow | grep -v grep | wc -l` -eq 1 ]]; then
        killall goflow
    fi
    isRunning="yes"
    if [[ -z `cat /tmp/goflow2.log` ]]; then
        echo -e "${RED}[ERROR]${END} ${RED}6343端口可能无法建立udp连接，或远程sflow无数据发送${END}"
    else
        echo -e "${BLUE}[INFO]${END} ${GREEN}开始进行第${i}次计算${END}"
        check_ttl /tmp/goflow2.log
        if [[ $i == ${num} ]]; then
            if [[ -z $(cat /tmp/check_nat.tmp 2>/dev/null) ]]; then
                echo -e "${BLUE}[INFO]${END} ${GREEN}没有发现共享上网用户！${END}${YELLOW}可能样本量不够，请尝试增大循环圈数.${END}"
            else   
                if [[ -f /tmp/check_nat.tmp ]]; then
                    cat /tmp/check_nat.tmp | sort | uniq -c | sort -nr > /tmp/check_nat.tmp1
                    while read line
                    do 
                        if [[ `cat /tmp/check_nat.tmp2 | sort | uniq | grep $(echo ${line} | awk '{print $2}') | wc -l` != 1 ]]; then
                            COLOR="${RED}"
                        else
                            COLOR="${CYAN}"
                        fi
                        echo -e "${BLUE}[INFO]${END} ${PURPLE}存在用户IP：$(echo ${line} | awk '{print $2}'), MAC：$(echo ${line} | awk '{print $3}')共享上网！${COLOR}权重: $(echo ${line} | awk '{print $1}')${END}${END}"
                    done < /tmp/check_nat.tmp1
                    rm -f /tmp/check_nat.tmp1 /tmp/check_nat.tmp /tmp/check_nat.tmp2 /tmp/goflow2.log
                    deny_fw "udp" "6344"
                    echo -e "${BLUE}[INFO]${END} ${GREEN}退出！${END}"
                fi
            fi
            break
        fi
        i=$((i+1))
    fi
done
exit 0