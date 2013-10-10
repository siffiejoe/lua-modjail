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
a function that creates and sets a proxy table as global environment,
which forwards `__index` requests to the real global environment,
replacing all tables with forwarding proxy tables, and certain
functions (e.g. `require`) with safer versions.

If you want to `require` a module that modifies the global environment
(e.g. [compat52.lua][3]) you have to do it *before* you
`require( "modjail" )`.

In case you have written your own searcher/loader function for Lua
modules, and you want to provide isolated environments for them too,
the return value of the `require` call for `modjail` is a function
that creates proxy environments used for the jails. Use it like this:

```lua
local make_jail = require( "modjail" )
local chunk = loadfile( "mod.lua", "bt", make_jail( _ENV ) )
```

##                            Disclaimer                            ##

`modjail` is intended for taming "unfriendly" Lua modules, *not* for
sandboxing malicious code. There are at least the following "security
holes" that allow a jailed module to modify the real global
environment:

*   `load`, `loadstring`, `loadfile` (execute code in real global env)
*   `dofile` (execute code in real global env)
*   `module` (allows "reopening" modules, Lua 5.1)
*   `getfenv` (e.g. on the main chunk, Lua 5.1)
*   `debug.*` (registry, upvalues, etc.)

"Fixing" the last three would seriously limit their usefulness.

  [1]: https://github.com/stevedonovan/Penlight/blob/master/lua/pl/strict.lua
  [2]: https://github.com/Yonaba/strictness/
  [3]: https://github.com/hishamhm/lua-compat-5.2/


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

modjail is *copyrighted free software* distributed under the MIT
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

