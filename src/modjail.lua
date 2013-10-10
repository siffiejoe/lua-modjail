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
  local getmetatable = getmetatable
  if package_seeall then
    assert( getmetatable )
  end
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
  wrappers[ module ] = function( root, cache )
    -- TODO
    return module
  end

  local dofile = dofile or false
  local loadfile = loadfile or false
  if dofile then
    assert( loadfile )
  end
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
  local mod, msg = package_searchpath( modname, package_path )
  if mod then
    local jail = _G
    if not whitelist[ modname ] then
      jail = make_jail( _G, _G, {} )
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
    return make_jail( v, v, {} )
  end
} )

