#!/bin/bash

for file in `svn status | awk '{print $2}' | grep '\.lua'`;
do
	luacheck ${file}
done
