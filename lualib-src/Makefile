CFLAGS = -fPIC -O3 -Wall -std=gnu99 
CFLAGS += -I../skynet-dist/3rd/lua

CPPFLAGS = -g -fPIC -Wall -std=c++0x 

LFLAGS = -shared
DEST=../luaclib

HASH_SRC = lua-hash.c
HASH_SO = $(DEST)/hash.so
PROTOBUF_SO = $(DEST)/protobuf.so
SOCKET_SO = $(DEST)/socket.so
JSON_SO = $(DEST)/cjson.so

all: $(HASH_SO) $(PROTOBUF_SO) $(SOCKET_SO) $(JSON_SO)

$(DEST):
	mkdir -p $@

$(HASH_SO): $(HASH_SRC) $(DEST) 
	$(CC) $(LFLAGS) -o $@ $(CFLAGS) $<

$(PROTOBUF_SO):
	cd pbc && $(MAKE) clean && $(MAKE)
	cd pbc/binding/lua53 &&  $(MAKE) clean && $(MAKE)
	cp pbc/binding/lua53/protobuf.so $@
	cp pbc/binding/lua53/protobuf.lua ../lualib

$(SOCKET_SO):
	cd luasocket-3.0-rc1 && $(MAKE) linux LUAV=5.3
	cp luasocket-3.0-rc1/src/socket.so.3.0-rc1 $@
	
$(JSON_SO):
	cd lua-cjson-2.1.0 && $(MAKE)
	cp lua-cjson-2.1.0/cjson.so $@
	
clean:
	$(RM) $(HASH_SO)  $(PROTOBUF_SO)  $(SOCKET_SO)

.PHONY: all clean
