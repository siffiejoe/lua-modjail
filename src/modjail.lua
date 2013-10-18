-- Replaces the Lua module searcher with a function that loads the lua
-- code with a proxy of the global environment that doesn't permit
-- modifications.

local assert = assert
local V = assert( _VERSION )
local _G = assert( _G )
local error = assert( error )
local next = assert( next )
local type = assert( type )
local tostring = assert( tostring )
local select = assert( select )
local loadfile = assert( loadfile )
local setmetatable = assert( setmetatable )
local setfenv = V == "Lua 5.1" and assert( setfenv )
local require = assert( require )
local string = require( "string" )
local debug = require( "debug" )
local package = require( "package" )
local s_match = assert( string.match )
local s_gmatch = assert( string.gmatch )
local getmetatable = assert( debug.getmetatable )
local package_path = assert( package.path )
local package_preload = assert( package.preload )
local package_loaded = assert( package.loaded )
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
  local s_gsub = assert( string.gsub )

  local delim = s_gsub( s_match( package_config, "^(.-)\n" ), "%%", "%%%%" )

  function package_searchpath( name, path )
    local pname = s_gsub( s_gsub( name, "%.", delim ), "%%", "%%%%" )
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


-- debug flag
local modjail_debug = false


local intmax = 2^31

-- make a function that emulates the # operator for wrapped tables
local function make_len( orig )
  return function( t )
    local len = #orig
    local p, q = len, len+1
    -- double q on every step to find a nil in t
    while t[ q ] ~= nil do
      p, q = q, 2*q
      if q > intmax then
        -- use linear search on malicious table
        repeat
          len = len + 1
        until t[ len ] == nil
        return len-1
      end
    end
    -- use binary search between p and q
    while q > p + 1 do
      local sum = p + q
      local mid = sum % 2 == 0 and sum/2 or (sum+1)/2
      if t[ mid ] == nil then
        q = mid
      else
        p = mid
      end
    end
    return p
  end
end


-- make a function that emulates `next` on wrapped tables
local function next_wrapped( orig, state, var )
  local val
  repeat
    var, val = next( state, var )
  until var == nil or orig[ var ] == nil
  if var ~= nil then
    return var, val
  end
end

local function make_next( orig, oiter, ostate, ovar )
  local pc = 1
  return function( state, var )
    if pc < 3 then
      if pc == 1 then -- first call
        var, pc = ovar, 2
      end
      local k, v = oiter( ostate, var )
      if k ~= nil then
        local new_v = state[ k ]
        if new_v ~= nil then v = new_v end
        return k, v
      else
        pc = 3
        return next_wrapped( orig, state, nil )
      end
    else -- iterate over excess elements in wrapped table
      return next_wrapped( orig, state, var )
    end
  end
end


-- some functions need to be wrapped to not break the jail
local wrappers = {}


-- create a proxy of the global environment and any sub tables
local function make_jail( id, root, original, cache )
  local t = type( original )
  if t ~= "table" and (t ~= "function" or not wrappers[ original ]) then
    return original
  end
  if cache[ original ] then
    return cache[ original ]
  end
  local f_handler = wrappers[ original ]
  if f_handler then
    local w = f_handler( id, root, cache )
    cache[ original ] = w
    return w
  else -- original is table:
    local new_env = {}
    local s = "jail("..tostring( id )..") "..tostring( new_env )
    cache[ original ] = new_env
    local wrapped_len = make_len( original )
    return setmetatable( new_env, {
      __index = function( t, k )
        local v = make_jail( id, root, original[ k ], cache )
        t[ k ] = v
        return v
      end,
      __call = function( t, ... )
        return original( ... )
      end,
      __len = wrapped_len,
      __pairs = function( t )
        local mt = getmetatable( original )
        if type( mt ) == "table" and
           type( mt.__pairs ) == "function" then
          return make_next( original, mt.__pairs( original ) ), t, nil
        else
          return make_next( original, next, original, nil ), t, nil
        end
      end,
      __tostring = function() return s end,
      __metatable = "jailed environment",
    } )
  end
end


local function is_wrapper( t )
  if type( t ) == "table" then
    local mt = getmetatable( t )
    return type( mt ) == "table" and
           mt.__metatable == "jailed environment"
  else
    return false
  end
end


local require_sentinel

do
  local function nonraw_ipairs_iterator( state, var )
    var = var + 1
    local v = state[ var ] -- use non-raw access
    if v ~= nil then
      return var, v
    end
  end

  local function nonraw_ipairs( t )
    local mt = getmetatable( t )
    if type( mt ) == "table" and
       type( mt.__ipairs ) == "function" then
      return mt.__ipairs( t )
    end
    return nonraw_ipairs_iterator, t, 0
  end

  wrappers[ ipairs or false ] = function( id, root, cache )
    return nonraw_ipairs
  end


  if V == "Lua 5.1" then
    local function lua52_pairs( t )
      local mt = getmetatable( t )
      if type( mt ) == "table" and
         type( mt.__pairs ) == "function" then
        return mt.__pairs( t )
      end
      return next, t, nil
    end

    wrappers[ pairs or false ] = function( id, root, cache )
      return lua52_pairs
    end
  end


  wrappers[ require ] = function( id, root, cache )
    local isolated_pl = make_jail( id, root, package_loaded, cache )
    return function( modname )
      local tmn = type( modname )
      if tmn ~= "string" then
        error( "bad argument #1 to 'require' (string expected, got "..
               tmn..")", 2 )
      end
      local iplmn = isolated_pl[ modname ]
      if iplmn ~= nil and
         (V ~= "Lua 5.1" or iplmn ~= require_sentinel) then
        return iplmn
      end
      local v = require( modname )
      return make_jail( id, root, v, cache )
    end
  end

  wrappers[ package.seeall or false ] = function( id, root, cache )
    return function( m )
      local tm = type( m )
      if tm ~= "table" then
        error( "bad argument #1 to 'seeall' (table expected, got "..
               tm..")", 2 )
      end
      local mt = getmetatable( m )
      if mt == nil then
        mt = {}
        setmetatable( m, mt )
      end
      if type( mt ) == "table" then
        if mt.__metatable == "jailed environment" then
          error( "attempt to call 'package.seeall' on  "..tostring( t ), 2 )
        end
        mt.__index = cache[ root ]
      end
      return m
    end
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

  local function pushmodule( modname, id, root, cache )
    local isolated_pl = make_jail( id, root, package_loaded, cache )
    local t = isolated_pl[ modname]
    if type( t ) ~= "table" then
      local is_new
      t, is_new = findtable( cache[ root ], modname )
      if t == nil or not is_new then
        error( "name conflict for module '"..modname.."'", 3 )
      end
      local plmn = package_loaded[ modname ]
      if plmn == nil or
         (V == "Lua 5.1" and plmn == require_sentinel) then
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
    local debug_getinfo = assert( debug.getinfo )
    local debug_setupvalue = assert( debug.setupvalue )
    function set_env( mod )
      local info = debug_getinfo( 3, "f" )
      debug_setupvalue( info.func, 1, mod )
    end
  else
    function set_env() end
  end

  wrappers[ module or false ] = function( id, root, cache )
    return function( modname, ... )
      local tmn = type( modname )
      if tmn ~= "string" then
        error( "bad argument #1 to 'module' (string expected, got "
               ..tmn..")", 2 )
      end
      local mod = pushmodule( modname, id, root, cache )
      if mod._NAME == nil then
        modinit( mod, modname )
      end
      set_env( mod )
      dooptions( mod, ... )
      return mod
    end
  end


  wrappers[ dofile or false ] = function( id, root, cache )
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
  wrappers[ load ] = function( id, root, cache )
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

  wrappers[ loadfile ] = function( id, root, cache )
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
  wrappers[ loadstring ] = function( id, root, cache )
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

  wrappers[ setmetatable ] = function( id, root, cache )
    if not modjail_debug then return setmetatable end
    return function( t, ... )
      if is_wrapper( t ) then
        error( "attempt to call 'setmetatable' on "..tostring( t ), 2 )
      end
      return setmetatable( t, ... )
    end
  end

  wrappers[ next ] = function( id, root, cache )
    if not modjail_debug then return next end
    return function( t, ... )
      if is_wrapper( t ) then
        error( "attempt to call 'next' on "..tostring( t ), 2 )
      end
      return next( t, ... )
    end
  end

  local table = table
  if table then
    local table_insert = table.insert or false
    wrappers[ table_insert ] = function( id, root, cache )
      if not modjail_debug then return table_insert end
      return function( t, ... )
        if is_wrapper( t ) then
          error( "attempt to call 'table.insert' on "..tostring( t ), 2 )
        end
        return table_insert( t, ... )
      end
    end

    local table_remove = table.remove or false
    wrappers[ table_remove ] = function( id, root, cache )
      if not modjail_debug then return table_remove end
      return function( t, ... )
        if is_wrapper( t ) then
          error( "attempt to call 'table.remove' on "..tostring( t ), 2 )
        end
        return table_remove( t, ... )
      end
    end

    local table_concat = table.concat or false
    wrappers[ table_concat ] = function( id, root, cache )
      if not modjail_debug then return table_concat end
      return function( t, ... )
        if is_wrapper( t ) then
          error( "attempt to call 'table.concat' on "..tostring( t ), 2 )
        end
        return table_concat( t, ... )
      end
    end

    local table_sort = table.sort or false
    wrappers[ table_sort ] = function( id, root, cache )
      if not modjail_debug then return table_sort end
      return function( t, ... )
        if is_wrapper( t ) then
          error( "attempt to call 'table.sort' on "..tostring( t ), 2 )
        end
        return table_sort( t, ... )
      end
    end

    local table_unpack = table.unpack or unpack or false
    wrappers[ table_unpack ] = function( id, root, cache )
      if not modjail_debug then return table_unpack end
      return function( t, ... )
        if is_wrapper( t ) then
          error( "attempt to call 'unpack'/'table.unpack' on "..
                 tostring( t ), 2 )
        end
        return table_unpack( t, ... )
      end
    end

    local table_maxn = table.maxn or false
    wrappers[ table_maxn ] = function( id, root, cache )
      if not modjail_debug then return table_maxn end
      return function( t )
        if is_wrapper( t ) then
          error( "attempt to call 'table.maxn' on  "..tostring( t ), 2 )
        end
        return table_maxn( t )
      end
    end
  end

end


-- cache caches for shared environments
local cache_cache = {}

-- use normal _G or shared envs for modules in this set
local whitelist = {}

-- the replacement searcher
local function jailed_lua_searcher( modname )
  assert( type( modname ) == "string" )
  local fn, msg = package_searchpath( modname, package_path )
  if not fn then
    return msg
  end
  local jail, id = _G, modname
  local env_id = whitelist[ modname ]
  if env_id ~= false then
    local cache
    if env_id then
      cache = cache_cache[ env_id ] or {}
      cache_cache[ env_id ] = cache
      id = env_id
    else
      cache = {}
    end
    jail = make_jail( id, _G, _G, cache )
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

-- detect require sentinel
if V == "Lua 5.1" then
  package_preload[ "modjail.detect" ] = function()
    require_sentinel = package_loaded[ "modjail.detect" ]
  end
  require( "modjail.detect" )
end

-- make debug submodule available
package_preload[ "modjail.debug" ] = function()
  modjail_debug = true
end

-- seal string metatable
do
  local mt = getmetatable( "" )
  if type( mt ) == "table" then
    mt.__metatable = "sealed by modjail"
  end
end


-- provide access to whitelist *and* make_jail function
return setmetatable( whitelist, {
  __call = function( _, id, v, c )
    assert( type( v ) == "table", "environment must be a table" )
    c = c or {}
    assert( type( c ) == "table", "cache must be a table" )
    return make_jail( id, v, v, c )
  end
} )

