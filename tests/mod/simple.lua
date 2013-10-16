local string = require( "string" )

testarray[ 2 ] = "x"
testarray[ 4 ] = "y"
print( "length of testarray:", #testarray )
print( "ipairs:" )
for i,v in ipairs( testarray ) do
  print( i, v )
end
testtable.b = "x"
testtable.d = "y"
print( "pairs:" )
for k,v in pairs( testtable ) do
  print( k, v )
end

print( "isolated vs. global environment inside 'mod.simple'" )
assert( not comp( _G ) )
assert( not comp( require, "require" ) )
assert( not comp( table, "table" ) )
assert( comp( table.concat, "table", "concat" ) )
assert( not comp( string, "string" ) )
assert( comp( string.match, "string", "match" ) )
assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
assert( not comp( testtable.b, "testtable", "b" ) )
assert( not comp( testtable.d, "testtable", "d" ) )

_G = nil
string.match = "no match"

local jail = require( "modjail" )
jail[ "mod.nwl" ] = false -- should *not* work from within isolation!
print( "loading 'mod.nwl' ..." )
local nwl = require( "mod.nwl" )

require = false
if loadstring then
  assert( loadstring( "table.insert = 'no insert anymore!'" ) )()
end
dofile( "./delinsert.lua" )
assert( loadfile( "./delinsert.lua" ) )()
local code, i = { "table.insert = ", "'no insert anymore!'" }, 0
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
  assert( not comp( table, "table" ) )
  assert( comp( table.concat, "table", "concat" ) )
  assert( not comp( table.insert, "table", "insert" ) )
  assert( not comp( string, "string" ) )
  assert( not comp( string.match, "string", "match" ) )
  assert( not comp( package.loaded.math, "package", "loaded", "math" ) )
  assert( not comp( package.loaded.modjail, "package", "loaded", "modjail" ) )
end

return M

