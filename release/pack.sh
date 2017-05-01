#!/bin/bash

CUR_DIR=$(dirname $(readlink -f $0))
SRC_DIR=$CUR_DIR/..
DEST_DIR=$CUR_DIR/sf_server
BUILD_DIR=$CUR_DIR/build

# Clear destination directory
if [ -d "$DEST_DIR" ]; then
  rm -rf $DEST_DIR
fi
mkdir -p $DEST_DIR

# Make log, directories
mkdir -p $DEST_DIR/log
mkdir -p $DEST_DIR/busilog
mkdir -p $DEST_DIR/business
mkdir -p $DEST_DIR/upload

cd $SRC_DIR
make rpc

# Copy files
FILES=(\
  center.sh   \
  common      \
  cservice    \
  game.sh     \
  logger.sh   \
  login.sh    \
  luaclib     \
  lualib      \
  Makefile    \
  proto       \
  python      \
  service     \
  start       \
)
for file in ${FILES[*]} ; do
  cp -r $SRC_DIR/$file $DEST_DIR
done

if [ -f $SRC_DIR/data ]; then
  mkdir -p $DEST_DIR/data
  cp $SRC_DIR/data/*.json $DEST_DIR/data
fi

SKYNET_DIR=$SRC_DIR/skynet-dist
SKYNET_DEST_DIR=$DEST_DIR/skynet-dist
mkdir -p $SKYNET_DEST_DIR
SKYNET_FILES=(\
  cservice \
  luaclib  \
  lualib   \
  service  \
  skynet   \
)
for file in ${SKYNET_FILES[*]]} ; do
  cp -r $SKYNET_DIR/$file $SKYNET_DEST_DIR
done

mv $DEST_DIR/start/server_dependency.sh $DEST_DIR/start/server_dependency.sh_template
mv $DEST_DIR/common/clustername.lua $DEST_DIR/common/clustername.lua_template

# Don't deploy setting file which is dependent on server.
rm $DEST_DIR/common/settings.lua

#包名 fgame+时间+包类型
DATE=$(date '+%Y-%m-%d_%H_%M_%S')

cd $DEST_DIR
if [ -d "$BUILD_DIR" ]; then
    rm -rf $BUILD_DIR/*
else
    mkdir -p $BUILD_DIR
fi

tar -czf $BUILD_DIR/sf_server-"$DATE".tar.gz *

rm -rf $DEST_DIR

