#!/usr/bin/lua

package.path = "../src/?.lua;" .. package.path

function comp( v, ... )
  local s = "_G"
  local g = _G
  local n = select( '#', ... )
  for i = 1, select( '#', ... ) do
    local k = select( i, ... )
    if type( g ) == "table" then
      g = g[ k ]
    end
    if k:match( "^[%a_][%w_]*$" ) then
      if i == 1 then
        s = k
      else
        s = s .. "." .. k
      end
    else
      s = s .. "[ '" .. k .. "' ]"
    end
  end
  local eq = (v == g)
  print( eq and "[==]" or "[~=]", s,
         string.rep( "\t", math.max( 0, 3-math.ceil( #s / 8 ) ) ),
         v, g )
  return eq
end


local _G_before = _G
local require_before = require
local table_before = table
local t_concat_before = table.concat
local string_before = string
local s_match_before = string.match
local s_find_before = string.find
local pl_math_before = package.loaded.math

local jail = require( "modjail" )

print( "loading 'mod.simple' ..." )
local simple = require( "mod.simple" )

print( "calling module exported function" )
simple.func()

-- whitelist mod.wl module
jail[ "mod.wl" ] = true

print( "loading 'mod.wl' ..." )
local wl = require( "mod.wl" )

print( "loading 'mod.str' ..." )
local str = require( "mod.str" )

print( "global environment before vs. after!" )
assert( comp( _G_before ) )
assert( comp( require_before, "require" ) )
assert( comp( table_before, "table" ) )
assert( comp( t_concat_before, "table", "concat" ) )
assert( comp( string_before, "string" ) )
assert( comp( s_match_before, "string", "match" ) )
assert( comp( s_find_before, "string", "find" ) )
assert( comp( pl_math_before, "package", "loaded", "math" ) )
assert( comp( jail, "package", "loaded", "modjail" ) )

