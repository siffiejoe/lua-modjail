local string = require( "string" )

function string.myfunc()
end

myglobal = 1

print( "isolated vs. global environment inside 'mod.m1'" )
assert( not comp( _G ) )
assert( not comp( myglobal, "myglobal" ) )
assert( not comp( require, "require" ) )
assert( not comp( io, "io" ) )
assert( comp( io.open, "io", "open" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( string.myfunc, "string", "myfunc" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

return {
  string = string
}

