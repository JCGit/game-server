#!/bin/bash

CUR_DIR=$(dirname $(readlink -f $0))

if [ ! -f "$CUR_DIR/server_dependency.sh" ]; then
  echo "Lack of file $CUR_DIR/server_dependency.sh" && exit -1
fi

. $CUR_DIR/server_dependency.sh

cd $CUR_DIR"/.."

$GAME_ON && bash game.sh stop $GAME_EXIT_PORT
$LOGIN_ON && bash login.sh stop
$CENTER_ON && bash center.sh stop
