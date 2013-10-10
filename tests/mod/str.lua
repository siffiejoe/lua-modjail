module( "string", package.seeall )
local string = require( "string" )

print( "isolated vs. global environment inside 'mod.str'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( not comp( table, "table" ) )
assert( comp( table.concat, "table", "concat" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

find = "no such function"

