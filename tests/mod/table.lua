print( "testing operations on wrapped tables ..." )
testarray[ 2 ] = "x"
testarray[ 4 ] = "y"
testtable.b = "x"
testtable.d = "y"
print( "length of testarray:", #testarray )
assert( comp( testarray[ 1 ], "testarray", 1 ) )
assert( not comp( testarray[ 2 ], "testarray", 2 ) )
assert( not comp( testarray[ 4 ], "testarray", 4 ) )
assert( comp( testtable.a, "testtable", "a" ) )
assert( not comp( testtable.b, "testtable", "b" ) )
assert( not comp( testtable.d, "testtable", "d" ) )
print( "ipairs( testarray ):" )
for i,v in ipairs( testarray ) do
  print( i, v )
end
print( "pairs( testtable ):" )
for k,v in pairs( testtable ) do
  print( k, v )
end

print( "testing table.insert ..." )
local t = { 1, 2, 3 }
table.insert( t, 1, 0 )
for k,v in pairs( t ) do
  print( k, v )
end
--table.remove( arg )
--table.concat( arg )
--table.sort( arg )
if _VERSION == "Lua 5.1" then
  --unpack( arg )
else
  --table.unpack( arg )
end
--next( arg )
--setmetatable( arg, {} )
table.insert( arg, "dummy" )

return {}

