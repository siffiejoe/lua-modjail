#          modjail -- Isolated Environments for Lua Modules          #

##                           Introduction                           ##

New-style Lua modules don't set globals anymore -- at least in theory.
To ensure that, some people use helper modules like `strict.lua`
(which is distributed with the Lua 5.1 source code), [pl.strict][1],
or [strictness][2] to intercept reads/writes to the global table. This
module goes one step further and provides each and every Lua module
with its own private, isolated global environment. Changes to those
environments stay private to the particular module that made them.


##                           How It Works                           ##

```lua
require( "modjail" )
```
or
```Shell
lua -l modjail script.lua
```

When loaded, this module replaces the Lua loader/searcher function in
the `package.searchers` table (or `package.loaders` for Lua 5.1) with
a function that creates a (lazy) copy of the global environment for
the module chunk, and wraps certain functions (e.g. `require`) for
more effective sandboxing.

If you want to `require` a module that's supposed to modify the global
environment (e.g. [compat52.lua][3]) you have to do so *before* you
`require( "modjail" )`, or you can use the return value of the
`require` call (a [func table][4]) to white-list a module name
(obviously that only works when used before you load the module for
the first time):

```lua
local jail = require( "modjail" )
jail[ "compat52" ] = false
require( "compat52" )  -- uses the normal global environment
```

Using values other than `false` for white-listing will make all
modules having the same value share their isolated environment.

You can also use the return value of the `require` call to implement
the jail functionality for your own module searchers/loaders. E.g.:

```lua
local jail = require( "modjail" )
local chunk = loadfile( "mod.lua", "bt", jail( "mod", _ENV ) )
```


##                            Disclaimer                            ##

`modjail` is intended for taming "unfriendly" Lua modules, *not* for
sandboxing malicious code. There are at least the following "security
holes" that allow a jailed module to modify the real global
environment:

*   `getfenv` (e.g. on the main chunk, or on userdata, Lua 5.1)
*   `setfenv` (using stack levels, Lua 5.1)
*   `debug.*` (registry, upvalues, etc.)

"Fixing" them would limit their usefulness.

*   Also `require` and `module` modify the real global environment by
    design (`package.loaded`), but at least other globals changes are
    restricted to the calling chunk.

Due to the lazy copying of the global environment (via `__index`
metamethods) there are some unwanted side-effects for the isolated
modules:

*   Metamethods on global tables (other than `__index`, `__call`, and
    `__len`) won't have any effect when used from an isolated
    environment.
*   The length operator `#`, if used on a wrapped global within an
    isolated environment, only works for Lua 5.2.
*   `table.*` functions won't work correctly on wrapped globals from
    another environment.

  [1]: https://github.com/stevedonovan/Penlight/blob/master/lua/pl/strict.lua
  [2]: https://github.com/Yonaba/strictness/
  [3]: https://github.com/hishamhm/lua-compat-5.2/
  [4]: http://lua-users.org/wiki/FuncTables


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

`modjail` is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    modjail (c) 2013 Philipp Janda

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

