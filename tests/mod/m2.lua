print( "isolated vs. global environment inside 'mod.m2'" )
assert( not comp( _G ) )
assert( not comp( myglobal, "myglobal" ) )
assert( not comp( require, "require" ) )
assert( not comp( io, "io" ) )
assert( comp( io.open, "io", "open" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( string.myfunc, "string", "myfunc" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
assert( comp( string, "package", "loaded", "mod.m1", "string" ) )

return {}

