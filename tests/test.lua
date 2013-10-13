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
  print( eq and "[==]" or "[~=]", s ..
         string.rep( "\t", math.max( 0, 4-math.floor( #s/8 ) ) ),
         v, g )
  return eq
end


local _G_before = _G
local require_before = require
local table_before = table
local t_concat_before = table.concat
local t_insert_before = table.insert
local string_before = string
local s_match_before = string.match
local pl_math_before = package.loaded.math

local jail = require( "modjail" )

print( "loading 'mod.simple' ..." )
local simple = require( "mod.simple" )

print( "calling module exported function" )
simple.func()

-- whitelist mod.wl module
jail[ "mod.wl" ] = false

print( "loading 'mod.wl' ..." )
local wl = require( "mod.wl" )

print( "loading 'mod.str' ..." )
print( pcall( require, "mod.str" ) )

print( "loading 'mod.mod' ..." )
local mod = require( "mod.mod" )

print( "loading 'mod.mod.sub' ..." )
local sub = require( "mod.mod.sub" )

-- shared environment
jail[ "mod.m1" ] = 1
jail[ "mod.m2" ] = 1
print( "loading 'mod.m1' ..." )
local m1 = require( "mod.m1" )
print( "loading 'mod.m2' ..." )
local m2 = require( "mod.m2" )

--[[
print( "loading 'mod.no.such.module' ..." )
print( xpcall( function() return require( "mod.no.such.module" ) end,
               debug.traceback ) )

print( "loading 'mod.broken' ..." )
print( xpcall( function() return require( "mod.broken" ) end,
               debug.traceback ) )
--]]

print( "global environment before vs. after!" )
assert( comp( _G_before ) )
assert( comp( require_before, "require" ) )
assert( comp( table_before, "table" ) )
assert( comp( t_concat_before, "table", "concat" ) )
assert( comp( t_insert_before, "table", "insert" ) )
assert( comp( string_before, "string" ) )
assert( comp( s_match_before, "string", "match" ) )
assert( comp( pl_math_before, "package", "loaded", "math" ) )
assert( comp( jail, "package", "loaded", "modjail" ) )

