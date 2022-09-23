#!/bin/bash

printSeparator() {
    echo "###############################"
}

tabOutput() {
    sed "s/^/\t/"
}

checkDeps() {
    which jq mpstat iostat > /dev/null
    rc=$?
    if [ $rc -ne 0 ]; then
        printf 'Do you want install all necessary dependencies (jq,sysstat) (y/n)? '
        read answer
        if [ "$answer" != "${answer#[Yy]}" ] ;then
            amiroot=`whoami`
            if [ "$amiroot" == "root" ]; then
                apt update -y && apt install -y jq sysstat
            else
                sudo apt update -y && sudo apt install -y jq sysstat
            fi
        else
            echo "Stop executing. We don't have all necessary deps"
            exit 0
        fi
    # else
    #     echo "all deps installed"
    fi
}

publishData() {
    printf '
    We want to publish all collected data on third party service
    This data could be accessed by other people and we arent responsible for it.
    Also collected data could contain some personal info.
    Do you agree to publish data (y/n)?'
    read answer
    if [ "$answer" != "${answer#[Yy]}" ] ;then
        link=$(cat $tmpf | curl -F 'sprunge=<-' http://sprunge.us 2> /dev/null)
        echo ""
        echo "  LINK TO YOUR REPORT: ${link}?sh"
        echo "  Provide this link to support team to help in your problem investigation"
        echo ""
    else
        echo ""
        echo "  Collected data saved in $tmpf"
        echo "  You can download this file, check it and provide manually to support team"
        echo ""
    fi
    
}

collectCPUData() {
    echo "Collect current CPU load stat"
    printSeparator
    mpstat 10 1 | tabOutput
    printSeparator
}

collectIOData() {
    echo "Collect current IO load stat"
    printSeparator
    iostat -d -x 10 1 | tabOutput
    printSeparator
}

collectHostInfo() {
    echo "CPU info"
    printSeparator
    echo "CPU model: $(cat /proc/cpuinfo  | grep 'model name' | head -1 | awk -F':' {'print $2'})" | tabOutput
    echo "CPU cores: $(cat /proc/cpuinfo  | grep 'processor' | wc -l)" | tabOutput
    echo "CPU available instructions: $(cat /proc/cpuinfo | grep 'flags' | head -1 | awk -F':' {'print $2'})" | tabOutput
    echo "CPU bugs: $(cat /proc/cpuinfo | grep 'bugs' | head -1 | awk -F':' {'print $2'})" | tabOutput
    printSeparator
    echo "Memroy Info"
    printSeparator
    cat /proc/meminfo | head -5 | tabOutput
    printSeparator
    echo "Disk Info"
    printSeparator
    lsblk | tabOutput
    echo ""
    df -h | tabOutput
    printSeparator
}

getEnvs() {
    echo "Collect envs which contain 'SUBSPACE' word..."
    printSeparator
    env | grep -i subspace | tabOutput
    # set | grep -i subspace | tabOutput
    printSeparator
}

getSystemdUnits() {
    # Try to find any units contain 'subspace' in name
    systemctl list-units --type=service | grep subspace | awk {'print $1'} | tabOutput
}

getSystemdUnitContent() {
    local unit=$1
    echo "Get content of unit file for $unit"
    printSeparator
    systemctl cat $unit | tabOutput
    printSeparator
}

getSystemdUnitStatus() {
    local unit=$1
    echo "Get status for $unit"
    printSeparator
    systemctl status $unit | tabOutput
    printSeparator
}

collectSystemdData() {
    for u in $(getSystemdUnits); do 
        getSystemdUnitContent $u
        getSystemdUnitStatus $u
    done
}

isDockerInstalled() {
    #echo "Check docker installation..."
    docker --version 2>&1 > /dev/null
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "false"
    else
        echo "true"
    fi
}

getDockerVersion() {
    echo "Get docker version"
    res=$(docker --version)
    printSeparator
    echo $res | tabOutput
    printSeparator
}

getDockerContainers() {
    docker ps -a | grep subspace | awk {'print $1'}
}

getDockerContainerInfo() {
    local cnt=$1
    echo "Get info for $cnt container"
    printSeparator
    docker ps -a | grep $cnt
    docker inspect $cnt | jq .[]."Name" | tabOutput
    docker inspect $cnt | jq .[]."State" | tabOutput
    docker inspect $cnt | jq .[]."Config"."Image" | tabOutput
    docker inspect $cnt | jq .[]."HostConfig"."RestartPolicy" | tabOutput
    docker inspect $cnt | jq .[]."Args" | tabOutput
    docker inspect $cnt | jq .[]."HostConfig"."NetworkMode" | tabOutput
    docker inspect $cnt | jq .[]."HostConfig"."PortBindings" | tabOutput
    docker inspect $cnt | jq .[]."Mounts" | tabOutput
    echo ""
}

collectDockerData() {
    getDockerVersion
    for c in $(getDockerContainers); do 
        getDockerContainerInfo $c
    done
}

collect() {
    getEnvs
    collectCPUData
    collectIOData
    collectHostInfo
    if [ "$(isDockerInstalled)" == "true" ]; then
        collectDockerData
    fi
    if [ $(getSystemdUnits | wc -l) -gt "0" ]; then
        collectSystemdData
    fi
}

checkDeps
tmpf=$(mktemp)
collect > $tmpf
publishData $tmpf
