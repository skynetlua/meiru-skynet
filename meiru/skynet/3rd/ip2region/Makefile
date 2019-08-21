all : ip2region.so

LUA_INC ?= ../lua

SRC_INC ?= ./

SHARED := -fPIC --shared
CFLAGS := -g -O2 -Wall -lstdc++ -std=c++0x -I.

lua-ip2region-scr = \
	ip2region.cpp \
	ip2region.c

ip2region.so : $(lua-ip2region-scr)
	gcc $(CFLAGS) $(SHARED) -I$(LUA_INC) -I$(SRC_INC) -o $@ $^

clean :
	rm -rf *.so
