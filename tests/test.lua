#!/usr/bin/lua

package.path = "../src/?.lua;" .. package.path

print( "testing modjail for", _VERSION )

function comp( v, ... )
  local s = "_G"
  local g = _G
  local n = select( '#', ... )
  for i = 1, select( '#', ... ) do
    local k = select( i, ... )
    if type( g ) == "table" then
      g = g[ k ]
    end
    if type( k ) == "string" then
      if k:match( "^[%a_][%w_]*$" ) then
        if i == 1 then
          s = k
        else
          s = s .. "." .. k
        end
      else
        s = s .. "[ '" .. tostring( k ) .. "' ]"
      end
    else
      s = s .. "[ " .. tostring( k ) .. " ]"
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
local io_before = io
local io_open_before = io.open
local io_write_before = io.write
local string_before = string
local s_match_before = string.match
local pl_math_before = package.loaded.math

local jail = require( "modjail" )
require( "modjail.debug" )

testarray = { 1, 2, 3 }
testtable = { a = 1, b = 2, c = 3 }
print( "loading 'mod.simple' ..." )
local simple = require( "mod.simple" )

print( "calling module exported function ..." )
simple.func()

-- whitelist mod.wl module
jail[ "mod.wl" ] = false

print( "loading 'mod.wl' ..." )
local wl = require( "mod.wl" )

print( "loading 'mod.str' ..." )
print( pcall( require, "mod.str" ) )

print( "loading 'mod.table' ..." )
print( pcall( require, "mod.table" ) )

print( "loading 'mod.mod' ..." )
local mod = require( "mod.mod" )

print( "loading 'mod.mod.sub' ..." )
local sub = require( "mod.mod.sub" )

-- shared environment
jail[ "mod.m1" ] = "mod.m*"
jail[ "mod.m2" ] = "mod.m*"
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

print( "loading 'mod.errmsg' ..." )
local errmsg = require( "mod.errmsg" )

print( "global environment before vs. after!" )
assert( comp( _G_before ) )
assert( comp( require_before, "require" ) )
assert( comp( io_before, "io" ) )
assert( comp( io_open_before, "io", "open" ) )
assert( comp( io_write_before, "io", "write" ) )
assert( comp( string_before, "string" ) )
assert( comp( s_match_before, "string", "match" ) )
assert( comp( pl_math_before, "package", "loaded", "math" ) )
assert( comp( jail, "package", "loaded", "modjail" ) )

