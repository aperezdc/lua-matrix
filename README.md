Matrix Client-Server API for Lua
================================

This is closely modelled after the official
[matrix-python-sdk](https://github.com/matrix-org/matrix-python-sdk).


Requirements
------------

* Lua 5.1, 5.2, 5.3, or LuaJIT — development and testing is only being done
  with 5.3, YMMV!
* The [cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php) module.
* One of the supported HTTP client libraries:
  - Daurnimator's excellent,
    [cqueues](http://25thandclement.com/~william/projects/cqueues.html)-based
    [http](https://github.com/daurnimator/lua-http) module.
  - [LuaSocket](http://w3.impa.br/~diego/software/luasocket) and (optionally)
    [LuaSec](https://github.com/brunoos/luasec) for TLS support.

If you use [LuaRocks](https://luarocks.org), you can get the dependencies
installed using the following commands:

```sh
luarocks install --server=http://luarocks.org/dev http
luarocks install lua-cjson
```

Self-promotion bit: If you use the [Z shell](http://www.zsh.org/) and want
something like
[virtualenv](http://docs.python-guide.org/en/latest/dev/virtualenvs/) for Lua,
please *do try* [RockZ](https://github.com/aperezdc/rockz).


Usage
-----

The library provides two levels of abstraction. The low-level layer wraps the
raw HTTP API. The high-level layer wraps the low-level layer and provides an
object model to perform actions on.

High-level `matrix.client` interface:

```lua
local client = require("matrix").client("http://localhost:8008")
local token = client:register_with_password("jdoe", "sup3rsecr1t")
local room = client:create_room("my_room_alias")
room:send_text("Hello!")
```

Low-level `matrix.api` interface:

```lua
local matrix = require("matrix")
local api = matrix.api("http://localhost:8080")
local response = api:register("m.login.password",
  { user = "jdoe", password = "sup3rsecr1t" })
api.token = response.token
handle_events(api:sync())
response = api:create_room({ alias = "my_room_alias" })
api:send_text(response.room_id, "Hello!")
```

### More Examples

For the low-level `matrix.api`:

* [examples/set-display-name.lua](./examples/set-display-name.lua)

For the high-level `matrix.client`:

* [examples/get-user-info.lua](./examples/get-user-info.lua)

More examples can be found in the [examples](./examples) subdirectory.
