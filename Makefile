all : clib busilogger rpc

.PHONY: cservice busilogger all help rpc server doc client clib 

test:
	./client/testclient.lua
clib:
	@cd lualib-src && $(MAKE)

busilogger: service-src/service_busilogger.c cservice
	gcc -fPIC --shared -g -O2 -Wall  $< -o cservice/busilogger.so -I./skynet-dist/skynet-src

cservice:
	mkdir -p cservice

rpc:
	@cd proto && $(MAKE)

clean:
	rm -f cservice/busilogger.so
	@cd lualib-src && $(MAKE) clean
	@cd proto && $(MAKE) clean
