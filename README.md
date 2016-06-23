Matrix Client-Server API for Lua
================================

This is closely modelled after the official
[matrix-python-sdk](https://github.com/matrix-org/matrix-python-sdk).


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
