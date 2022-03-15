use "net"
use "package:../../websocket"
use @printf[I32](fmt: Pointer[U8] tag, ...)

actor Main
  new create(env: Env) =>
    env.out.print("Start server")
    let tcplauth: TCPListenAuth = TCPListenAuth(env.root)

    let listener = WebSocketListener(tcplauth,
      EchoListenNotify, "0.0.0.0", "8989", 0, 16777216 + 4)

class EchoListenNotify is WebSocketListenNotify
  // A tcp connection connected, return a WebsocketConnectionNotify instance
  fun ref connected(): EchoConnectionNotify iso^ =>
    EchoConnectionNotify

  fun ref not_listening() =>
    @printf("Failed listening\n".cstring())

class EchoConnectionNotify is WebSocketConnectionNotify
  // A websocket connection enters the OPEN state
  fun ref opened(conn: WebSocketConnection ref) =>
    @printf("New client connected\n".cstring())

  // UTF-8 text data received
  fun ref text_received(conn: WebSocketConnection ref, text: String) =>
    // Send the text back
    conn.send_text(text)

  // Binary data received
  fun ref binary_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
    conn.send_binary(data)

  // A websocket connection enters the CLOSED state
  fun ref closed(conn: WebSocketConnection ref) =>
    @printf("Connection closed\n".cstring())
