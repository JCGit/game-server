
all: ../common/rpc_info.lua game.pb

.PHONY: all help clean

PC = protoc
GAME_PROTO = $(wildcard ./proto/*.proto)

help :
	@echo "usage:"
	@echo "    make 更新proto输出"

../common/rpc_info.lua : google.pb $(GAME_PROTO)
	$(PC) --rpc_out=../common --plugin=protoc-gen-rpc=gen_rpc.lua -Iproto -I. $(GAME_PROTO)

game.pb : $(GAME_PROTO)
	$(PC) -o $@ -Iproto -I. --include_imports $^

SYS_PROTO = google/protobuf/compiler/plugin.proto \
			google/protobuf/descriptor.proto \
			proto/rpc.proto

google.pb : $(SYS_PROTO)
	@$(PC) -o $@ --include_imports $^

clean :
	rm -f game.pb ../common/rpc_info.lua

