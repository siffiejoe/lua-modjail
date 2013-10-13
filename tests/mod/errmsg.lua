print( "checking error messages of wrapped functions ..." )
print( pcall( require, false ) )
print( pcall( package.seeall, false ) )
print( pcall( module, false ) )
print( pcall( dofile, "./no_such_file.lua" ) )
print( pcall( dofile, "./mod/broken.lua" ) )
print( pcall( dofile, "./rterror.lua" ) )

return {}

