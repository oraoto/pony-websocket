use "package:../../websocket"

actor Main
  new create(env: Env) =>
    env.out.print("Start server")

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
  fun ref opened(conn: WebSocketConnection tag) =>
    @printf[I32]("New client connected\n".cstring())

  // UTF-8 text data received
  fun ref text_received(conn: WebSocketConnection tag, text: String) =>
    // Send the text back
    conn.send_text(text)

  // Binary data received
  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8] val) =>
    conn.send_binary(data)

  // A websocket connection enters the CLOSED state
  fun ref closed() =>
    @printf[I32]("Connection closed\n".cstring())
