use "net"
use "time"
use "collections"

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
   fun ref connected(conn: WebSocketConnection ref) =>
    None
