-- Replaces the Lua module searcher with a function that loads the lua
-- code with a proxy of the global environment that doesn't permit
-- modifications.

local assert = assert
local V = assert( _VERSION )
local _G = assert( _G )
local error = assert( error )
local type = assert( type )
local loadfile = assert( loadfile )
local getmetatable = assert( getmetatable )
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
  local string = require( "string" )
  local io = require( "io" )
  local package_config = assert( package.config )
  local table_concat = assert( table.concat )
  local io_open = assert( io.open )
  local s_sub = assert( string.sub )
  local s_gsub = assert( string.gsub )
  local s_gmatch = assert( string.gmatch )

  local delim = s_gsub( s_sub( package_config, 1, 1 ), "(%%)", "%%%1" )

  function package_searchpath( name, path )
    local pname = s_gsub( s_gsub( name, "%.", delim ), "(%%)", "%%%1" )
    local msg = {}
    for subpath in s_gmatch( path, "[^;]+" ) do
      local fpath = s_gsub( subpath, "%?", pname )
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


-- some functions need to be wrapped to not break the jail
local wrappers = {}

-- create a proxy of the global environment and any sub tables
local function make_jail( root, original, cache )
  local t = type( original )
  if t ~= "table" and (t ~= "function" or not wrappers[ original ]) then
    return original
  end
  if cache[ original ] then
    return cache[ original ]
  end
  local f_handler = wrappers[ original ]
  if f_handler then
    local w = f_handler( root, cache )
    cache[ original ] = w
    return w
  else -- original is table:
    local new_env = {}
    cache[ original ] = new_env
    return setmetatable( new_env, {
      __index = function( t, k )
        local v = make_jail( root, original[ k ], cache )
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


do
  wrappers[ require ] = function( root, cache )
    return function( modname )
      local v = require( modname )
      return make_jail( root, v, cache )
    end
  end

  local package_seeall = package.seeall or false
  wrappers[ package_seeall ] = function( root, cache )
    return function( m )
      local mt = getmetatable( m )
      if mt == nil then
        mt = {}
        setmetatable( m, mt )
      end
      if type( mt ) == "table" then
        mt.__index = cache[ root ]
      end
      return m
    end
  end

  local module = module or false
  local package_loaded = package.loaded
  local select = select
  local next = next
  local s_gmatch, s_match
  if module then
    assert( package_loaded )
    assert( select )
    assert( next )
    local string = require( "string" )
    s_gmatch = assert( string.gmatch )
    s_match = assert( string.match )
  end

  local function findtable( base, modname )
    local t, is_new = base, true
    for key in s_gmatch( modname, "[^%.]+" ) do
      if t[ key ] == nil then
        t[ key ] = {}
        is_new = true
      else
        is_new = false
      end
      t = t[ key ]
      if type( t ) ~= "table" then
        return nil
      end
    end
    return t, is_new
  end

  local function pushmodule( modname, root, cache )
    local isolated_pl = make_jail( root, package_loaded, cache )
    local t = isolated_pl[ modname]
    if type( t ) ~= "table" then
      local is_new
      t, is_new = findtable( cache[ root ], modname )
      if t == nil or not is_new then
        error( "name conflict for module '"..modname.."'", 3 )
      end
      if package_loaded[ modname ] == nil then
        package_loaded[ modname ] = t
        cache[ t ] = t
      end
      isolated_pl[ modname ] = t
    else
      error( "redefinition of module '"..modname.."'", 3 )
    end
    return t
  end

  local function modinit( mod, modname )
    mod._NAME = modname
    mod._M = mod
    mod._PACKAGE = s_match( modname, "^(.+%.)[^%.]+$" ) or ""
  end

  local function dooptions( mod, ... )
    for i = 1, select( '#', ... ) do
      local func = select( i, ... )
      if type( func ) == "function" then
        func( mod )
      end
    end
  end

  local set_env
  if V == "Lua 5.1" then
    function set_env( mod )
      setfenv( 3, mod )
    end
  elseif V == "Lua 5.2" then
    local debug_getinfo, debug_setupvalue
    if module then
      local debug = require( "debug" )
      debug_getinfo = assert( debug.getinfo )
      debug_setupvalue = assert( debug.setupvalue )
    end
    function set_env( mod )
      local info = debug_getinfo( 3, "f" )
      debug_setupvalue( info.func, 1, mod )
    end
  else
    function set_env() end
  end

  wrappers[ module ] = function( root, cache )
    return function( modname, ... )
      assert( type( modname ) == "string",
              "modul name must be a string" )
      local mod = pushmodule( modname, root, cache )
      if mod._NAME == nil then
        modinit( mod, modname )
      end
      set_env( mod )
      dooptions( mod, ... )
      return mod
    end
  end

  local dofile = dofile or false
  wrappers[ dofile ] = function( root, cache )
    return function( fn )
      local chunk, msg = loadfile( fn, "bt", cache[ root ] )
      if not chunk then
        error( msg, 2 )
      else
        if setfenv then
          setfenv( chunk, cache[ root ] )
        end
        return chunk()
      end
    end
  end

  local load = load or false
  wrappers[ load ] = function( root, cache )
    return function( fns, n, m, env )
      if env == nil then
        local chunk, msg = load( fns, n, m, cache[ root ] )
        if chunk then
          if setfenv then
            setfenv( chunk, cache[ root ] )
          end
          return chunk
        end
        return nil, msg
      else
        return load( fns, n, m, env )
      end
    end
  end

  wrappers[ loadfile ] = function( root, cache )
    return function( fn, m, env )
      if env == nil then
        local chunk, msg = loadfile( fn, m, cache[ root ] )
        if chunk then
          if setfenv then
            setfenv( chunk, cache[ root ] )
          end
          return chunk
        else
          return nil, msg
        end
      else
        return loadfile( fn, m, env )
      end
    end
  end

  local loadstring = loadstring or false
  wrappers[ loadstring ] = function( root, cache )
    return function( fns, n, m, env )
      if env == nil then
        local chunk, msg = loadstring( fns, n, m, cache[ root ] )
        if chunk then
          if setfenv then
            setfenv( chunk, cache[ root ] )
          end
          return chunk
        end
        return nil, msg
      else
        return loadstring( fns, n, m, env )
      end
    end
  end
end


-- use normal _G for modules in this set
local whitelist = {}

-- the replacement searcher
local function jailed_lua_searcher( modname )
  assert( type( modname ) == "string" )
  local fn, msg = package_searchpath( modname, package_path )
  if not fn then
    return msg
  end
  local jail = _G
  if not whitelist[ modname ] then
    jail = make_jail( _G, _G, {} )
  end
  local mod, msg = loadfile( fn, "bt", jail )
  if not mod then
    error( "error loading module '"..modname.."' from file '"..fn..
           "':\n\t"..msg, 0 )
  end
  if setfenv then
    setfenv( mod, jail )
  end
  return mod, fn
end


assert( #package_searchers == 4, "package.searchers has been modified" )
package_searchers[ 2 ] = jailed_lua_searcher

-- seal string metatable
do
  local mt = getmetatable( "" )
  if type( mt ) == "table" then
    mt.__metatable = "sealed by modjail"
  end
end


-- provide access to whitelist *and* make_jail function
return setmetatable( whitelist, {
  __call = function( _, v )
    assert( type( v ) == "table", "environment must be a table" )
    return make_jail( v, v, {} )
  end
} )

