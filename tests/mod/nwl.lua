local string = require( "string" )

print( "isolated vs. global environment inside 'mod.nwl'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( not comp( io, "io" ) )
assert( comp( io.open, "io", "open" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

local M = {}

return M

