local string = require( "string" )
print( "module loading" )
print( "", "_G", _G )
print( "", "require", require )
print( "", "table", table )
print( "", "table.concat", table.concat )
print( "", "string", string )
print( "", "string.match", string.match )
print( "", "package.loaded.math", package.loaded.math )

_G = nil
require = false
table = 123
string.match = "no match"

local M = {}

function M.func()
  print( "", "_G", _G )
  print( "", "require", require )
  print( "", "table", table )
  print( "", "string", string )
  print( "", "string.match", string.match )
  print( "", "package.loaded.math", package.loaded.math )
end

return M

