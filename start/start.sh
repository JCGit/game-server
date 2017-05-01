#!/bin/bash

CUR_DIR=$(dirname $(readlink -f $0))

if [ ! -f "$CUR_DIR/server_dependency.sh" ]; then
  echo "Lack of file $CUR_DIR/server_dependency.sh" && exit -1
fi

GAME_DIR=$CUR_DIR"/../"

. $CUR_DIR/server_dependency.sh

cd $GAME_DIR

$CENTER_ON && bash center.sh start release common/config.center
$LOGIN_ON && bash login.sh start release common/config.login

# 停1s，有时前一个服务器启动慢了就连接不上了，导致后面的服务器启动不了
# 更好的做法是去除这种依赖
sleep 1s
$GAME_ON && bash game.sh start release common/config
