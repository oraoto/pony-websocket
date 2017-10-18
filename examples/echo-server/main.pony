use "package:../../"


actor Main
  new create(env: Env) =>
    env.out.print("Start server")

    try
      let listener = WebSocketListener(
        env.root as AmbientAuth,
        recover MyWebSocketListenNotify end,
        "127.0.0.1","8989")
    end

class MyWebSocketListenNotify is WebSocketListenNotify
  fun ref connected(): MyWebSocketConnectionNotify iso^ =>
    MyWebSocketConnectionNotify

class MyWebSocketConnectionNotify is WebSocketConnectionNotify
  fun ref opened(conn: WebSocketConnection tag) =>
    @printf[I32]("New client connected\n".cstring())
    None

  fun ref text_received(conn: WebSocketConnection tag, text: String) : Bool =>
    conn.send_text(text)
    true

  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8 val] val) : Bool =>
    conn.send_binary(data)
    true
