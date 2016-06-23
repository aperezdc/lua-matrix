Matrix Client-Server API for Lua
================================

This is closely modelled after the official
[matrix-python-sdk](https://github.com/matrix-org/matrix-python-sdk).


Requirements
------------

* Lua 5.1, 5.2, 5.3, or LuaJIT — development and testing is only being done
  with 5.3, YMMV!
* The [cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php) module.
* Daurnimator's excellent,
  [cqueues](http://25thandclement.com/~william/projects/cqueues.html)-based
  [http](https://github.com/daurnimator/lua-http) module.

If you use [LuaRocks](https://luarocks.org), you can get the dependencies
installed using the following commands:

```sh
luarocks install --server=http://luarocks.org/dev http
luarocks install lua-cjson
```


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
local matrix_api = require("matrix.api")
local api = matrix_api("http://localhost:8080")
local response = api:register("m.login.password",
  { user = "jdoe", password = "sup3rsecr1t" })
api.token = response.token
handle_events(api:initial_sync(1))
response = api:create_room({ alias = "my_room_alias" })
api:send_text(response.room_id, "Hello!")
```
