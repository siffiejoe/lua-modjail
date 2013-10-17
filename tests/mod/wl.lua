local string = require( "string" )

print( "isolated vs. global environment inside 'mod.wl'" )
assert( comp( _G ) )
assert( comp( require, "require" ) )
assert( comp( io, "io" ) )
assert( comp( io.open, "io", "open" ) )
assert( comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( comp( package.loaded.math, "package", "loaded", "math" ) )
assert( comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

local M = {}

return M

