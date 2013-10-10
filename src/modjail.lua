-- Replaces the Lua module searcher with a function that loads the lua
-- code with a proxy of the global environment that doesn't permit
-- modifications.

local assert = assert
local V = assert( _VERSION )
local _G = assert( _G )
local type = assert( type )
local next = assert( next )
local loadfile = assert( loadfile )
local setmetatable = assert( setmetatable )
local setfenv = V == "Lua 5.1" and assert( setfenv )
local require = assert( require )
local package = require( "package" )
local package_path = assert( package.path )
local package_searchers = assert( V == "Lua 5.1" and package.loaders
                                                 or package.searchers )
local package_searchpath = package.searchpath
if not package_searchpath then
  -- provide package.searchpath for Lua 5.1
  local table = require( "table" )
  local io = require( "io" )
  local package_config = assert( package.config )
  local table_concat = assert( table.concat )
  local io_open = assert( io.open )
  assert( ("").sub )
  assert( ("").gsub )
  assert( ("").gmatch )

  local delim = package_config:sub( 1, 1 ):gsub( "(%%)", "%%%1" )

  function package_searchpath( name, path )
    local pname = name:gsub( "%.", delim ):gsub( "(%%)", "%%%1" )
    local msg = {}
    for subpath in path:gmatch( "[^;]+" ) do
      local fpath = subpath:gsub( "%?", pname )
      local f = io_open( fpath, "r" )
      if f then
        f:close()
        return fpath
      end
      msg[ #msg+1 ] = "\n\tno file '" .. fpath .. "'"
    end
    return nil, table_concat( msg )
  end
end


-- create a proxy of the global environment and any sub tables
local function make_jail( original, cache )
  if type( original ) ~= "table" and original ~= require then
    return original
  end
  if cache[ original ] then
    return cache[ original ]
  end
  if original == require then
    local function my_require( modname )
      local v = require( modname )
      return make_jail( v, cache )
    end
    cache[ require ] = my_require
    return my_require
  else -- original is table:
    local new_env = {}
    cache[ original ] = new_env
    return setmetatable( new_env, {
      __index = function( t, k )
        local v = make_jail( original[ k ], cache )
        t[ k ] = v
        return v
      end,
      __call = function( t, ... )
        return original( ... )
      end,
      __metatable = "jailed environment",
    } )
  end
end


local whitelist = {}

-- the replacement searcher
local function jailed_lua_searcher( modname )
  assert( type( modname ) == "string" )
  local mod, msg = package_searchpath( modname, package_path )
  if mod then
    local jail = _G
    if not whitelist[ modname ] then
      jail = make_jail( _G, {} )
    end
    mod, msg = loadfile( mod, "bt", jail )
    if mod and setfenv then
      setfenv( mod, jail )
    end
  end
  return mod, msg
end


assert( #package_searchers == 4, "package.searchers has been modified" )
package_searchers[ 2 ] = jailed_lua_searcher


-- provide access to whitelist *and* make_jail function
return setmetatable( whitelist, {
  __call = function( _, v )
    return make_jail( v, {} )
  end
} )

