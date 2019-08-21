#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "ip2region.h"

static ip2region_entry ip2rEntry;

int lip_init(lua_State *L){
	const char *file_name = luaL_checkstring(L, 1);

	if ( ip2region_create(&ip2rEntry, file_name) == 0 ) {
        lua_pushboolean(L, 0);
        return 1;
    }

	lua_pushboolean(L, 1);
	return 1;
}

int lip_find(lua_State *L){
	const char *ip_str = luaL_checkstring(L, 1);

	datablock_entry datablock;
	memset(&datablock, 0x00, sizeof(datablock_entry));

	ip2region_btree_search_string(&ip2rEntry, (char *)ip_str, &datablock);
	
	lua_pushfstring(L, datablock.region);
	return 1;
}

int lip2long(lua_State *L){
	const char *ip_str = luaL_checkstring(L, 1);
	uint_t long_ip = ip2long((char *)ip_str);
	lua_pushinteger(L, long_ip);
	return 1;
}

int llong2ip(lua_State *L){
	lua_Integer ip_lone = luaL_checkinteger(L, 1);
	char ip_str[256] = {0};
	uint_t result = long2ip(ip_lone, ip_str);
	if (result == 1){
		lua_pushstring(L, ip_str);
		return 1;
	}
	
	lua_pushnil(L);
	return 1;
}

static const struct luaL_Reg l_methods[] = {
    { "init" , lip_init },
	{ "find" , lip_find },
	{ "ip2long" , lip2long },
	{ "long2ip" , llong2ip },
    {NULL, NULL},
};

LUALIB_API int luaopen_ip2region(lua_State* L)
{
	lua_newtable(L);
	luaL_newlib(L, l_methods);
	return 1;
}

