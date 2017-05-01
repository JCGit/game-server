#!/bin/bash

#参数1： 命令
# start[默认] 启动
# stop 停止
CMD=$1

#参数2： 类型
# release[默认] 后台启动
# debug 前台启动
MODE=$2

TMP=$PATH
. /etc/init.d/functions
PATH=$TMP

ulimit -c unlimited

COLOR_RED='\033[31m'
COLOR_GREEN='\033[32m'
COLOR_RESET='\033[0m'

CUR_PATH=$(dirname $(readlink -f $0))
PID_FILE=$CUR_PATH/game.pid

if [ -z "$3" ]; then
  CONFIG=$CUR_PATH/common/config
else
  CONFIG=$CUR_PATH/$3
fi

function check(){
  sts=$CUR_PATH"/common/settings.lua"
  if [ ! -f "$sts" ]; then
    echo -e "please make sure $COLOR_RED $sts $COLOR_RESET exist\n"
    exit 2
  fi
}

#后台启动
function back(){
  #git submodule update
  echo -n $"Starting gameserver: "
  $CUR_PATH/skynet-dist/skynet $CONFIG
  if [ $? -eq 0 ]; then
    success && echo
  else
    failure && echo
  fi
}

#前台启动
function view(){
  cd $CUR_PATH
  debug_cfg=$CUR_PATH/common/debug_cfg
  sed -e 's/^logger/--logger/' -e 's/daemon/--daemon/' $CONFIG > $debug_cfg
  $CUR_PATH/skynet-dist/skynet $debug_cfg
}

function proto(){
  cd $CUR_PATH"/proto"  && make
  cd -
}

function start(){
  check
  proto
  case "$MODE" in
    release)
    #sh sh/log_name.sh game
      back
      ;;
    debug)
      view
      ;;
    *)
      echo "mode[$MODE] invalid param, please sure [release|debug]"
      exit 2
  esac
}

function stop(){

  EXIT_PORT=$2
  if [ -z $EXIT_PORT ]; then
    EXIT_PORT=5210
  fi
  python python/stopHall.py $EXIT_PORT
  # Wait game server to complete saving data
  # sleep 10

  if [ ! -f $PID_FILE ] ;then
    echo "have no gameserver"
    exit 0
  fi

  pid=`cat $PID_FILE`
  exist_pid=`pgrep skynet | grep $pid`
  if [ -z "$exist_pid" ] ;then
    echo "have no gameserver"
    exit 0
  else
    echo -n $"$pid gameserver will killed"
    killproc -p $PID_FILE
    echo
  fi
}

case "$CMD" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "$0 start [release|debug config] | $0 stop port"
    exit 2
esac

