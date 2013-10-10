local string = require( "string" )

print( "isolated vs. global environment inside 'mod.simple'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( not comp( table, "table" ) )
assert( comp( table.concat, "table", "concat" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )

_G = nil
table = 123
string.match = "no match"

local jail = require( "modjail" )
jail[ "mod.nwl" ] = true -- should *not* work from within isolation!
print( "loading 'mod.nwl' ..." )
local nwl = require( "mod.nwl" )

require = false

local M = {}

function M.func()
  print( "isolated vs. global environment inside 'testmod.func()'" )
  assert( not comp( _G ) )
  assert( not comp( require, "require" ) )
  assert( not comp( table, "table" ) )
  assert( not comp( string, "string" ) )
  assert( not comp( string.match, "string", "match" ) )
  assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
  assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
end

return M

