local string = require( "string" )

print( "isolated vs. global environment inside 'mod.simple'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( not comp( io, "io" ) )
assert( comp( io.open, "io", "open" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

_G = nil
string.match = "no match"

local jail = require( "modjail" )
jail[ "mod.nwl" ] = false -- should *not* work from within isolation!
print( "loading 'mod.nwl' ..." )
local nwl = require( "mod.nwl" )

require = false
if loadstring then
  assert( loadstring( "io.write = 'no io.write anymore!'" ) )()
end
dofile( "./delwrite.lua" )
assert( loadfile( "./delwrite.lua" ) )()
local code, i = { "io.write = ", "'no io.write anymore!'" }, 0
local function loader()
  i = i + 1
  return code[ i ]
end
assert( load( loader ) )()

local M = {}

function M.func()
  print( "isolated vs. global environment inside 'testmod.func()'" )
  assert( not comp( _G ) )
  assert( not comp( require, "require" ) )
  assert( not comp( io, "io" ) )
  assert( comp( io.open, "io", "open" ) )
  assert( not comp( io.write, "io", "write" ) )
  assert( not comp( string, "string" ) )
  assert( not comp( string.match, "string", "match" ) )
  assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
  assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
end

return M

