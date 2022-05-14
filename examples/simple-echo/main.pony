use "net"
use "package:../../websocket"

use @printf[I32](fmt: Pointer[U8] tag, ...)

actor Main
  new create(env: Env) =>
    let tcplauth: TCPListenAuth = TCPListenAuth(env.root)
    let listener = WebSocketListener(tcplauth,
      recover SimpleServer(EchoWebSocketNotify) end,
      "127.0.0.1","8989")

actor EchoWebSocketNotify is SimpleWebSocketNotify

  be opened(conn: WebSocketConnection tag) =>
    @printf("New client connected\n".cstring())

  be text_received(conn: WebSocketConnection tag, text: String) =>
    conn.send_text_be(text)

  be binary_received(conn: WebSocketConnection tag, data: Array[U8] val) =>
    conn.send_binary_be(data)

  be closed(conn: WebSocketConnection tag) =>
    @printf("Connection closed\n".cstring())
