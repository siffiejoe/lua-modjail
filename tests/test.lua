#!/usr/bin/lua

package.path = "../src/?.lua;" .. package.path

print( "before jail" )
print( "", "_G", _G )
print( "", "require", require )
print( "", "table", table )
print( "", "table.concat", table.concat )
print( "", "string", string )
print( "", "string.match", string.match )
print( "", "package.loaded.math", package.loaded.math )

require( "modjail" )

print( "after jail" )
print( "", "_G", _G )
print( "", "require", require )
print( "", "table", table )
print( "", "table.concat", table.concat )
print( "", "string", string )
print( "", "string.match", string.match )
print( "", "package.loaded.math", package.loaded.math )

local mod = require( "testmod" )

print( "after module load" )
print( "", "_G", _G )
print( "", "require", require )
print( "", "table", table )
print( "", "table.concat", table.concat )
print( "", "string", string )
print( "", "string.match", string.match )
print( "", "package.loaded.math", package.loaded.math )

print( "calling module" )
mod.func()

