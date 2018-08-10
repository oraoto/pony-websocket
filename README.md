# pony-websocket

[![CircleCI](https://img.shields.io/circleci/project/github/oraoto/pony-websocket.svg)](https://circleci.com/gh/oraoto/pony-websocket/tree/master)
![stability](https://img.shields.io/badge/stability-experimental-red.svg)

WebSocket server for pony

It's RFC6455 conformant, see [test report](https://oraoto.github.io/pony-websocket/).

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* `stable add github oraoto/pony-websocket`
* `stable fetch` to fetch your dependencies
* `use "websocket"` to include this package
* `stable env ponyc` to compile your application

## Usage

The API is model after the [net](https://stdlib.ponylang.org/net--index) package and much simplified.

Here is a simple echo server:

```pony
use "websocket"

actor Main
  new create(env: Env) =>
    try
      let listener = WebSocketListener(
        env.root as AmbientAuth, EchoListenNotify, "127.0.0.1","8989")
    end

class EchoListenNotify is WebSocketListenNotify
  // A tcp connection connected, return a WebsocketConnectionNotify instance
  fun ref connected(): EchoConnectionNotify iso^ =>
    EchoConnectionNotify

class EchoConnectionNotify is WebSocketConnectionNotify
  // A websocket connection enters the OPEN state
  fun ref opened(conn: WebSocketConnection ref) =>
    @printf[I32]("New client connected\n".cstring())

  // UTF-8 text data received
  fun ref text_received(conn: WebSocketConnection ref, text: String) =>
    // Send the text back
    conn.send_text(text)

  // Binary data received
  fun ref binary_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
    conn.send_binary(data)

  // A websocket connection enters the CLOSED state
  fun ref closed(conn: WebSocketConnection ref) =>
    @printf[I32]("Connection closed\n".cstring())
```

An simplified API is also provided: [example](./examples/simple-echo/main.pony).

See more [examples](./examples).
