local string = require( "string" )
module( (...), package.seeall )
print( "isolated vs. global environment inside '".._NAME.."'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( comp( table.concat, "table", "concat" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
assert( not comp( mod.mod, "mod", "mod" ) )
assert( not comp( _M, "_M" ) )
assert( not comp( _NAME, "_NAME" ) )
assert( not comp( _PACKAGE, "_PACKAGE" ) )



module( (...)..".sub", package.seeall )
print( "isolated vs. global environment inside '".._NAME.."'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( comp( table.concat, "table", "concat" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
assert( not comp( mod.mod, "mod", "mod" ) )
assert( comp( mod.mod, "package", "loaded", "mod.mod" ) )
assert( not comp( mod.mod.sub, "mod", "mod", "sub" ) )
assert( comp( mod.mod.sub, "package", "loaded", "mod.mod.sub" ) )
assert( not comp( _M, "_M" ) )
assert( not comp( _NAME, "_NAME" ) )
assert( not comp( _PACKAGE, "_PACKAGE" ) )
