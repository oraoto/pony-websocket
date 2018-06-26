use "package:../../websocket"

actor Main
  new create(env: Env) =>
    env.out.print("Listening on port 8989")
    try
      WebSocketListener(
        env.root as AmbientAuth,
        MyListenNotify(env),
        "0.0.0.0",
        "8989")
    end

class MyListenNotify is WebSocketListenNotify
  let env: Env

  new iso create(env': Env) =>
    env = env'

  fun ref connected(): MyConnectionNotify iso^ =>
    MyConnectionNotify(env)

  fun ref not_listening() =>
    env.out.print("Not listening")

class MyConnectionNotify is WebSocketConnectionNotify
  let env: Env

  new iso create(env': Env) =>
    env = env'

  fun ref opened(conn: WebSocketConnection ref) =>
    env.out.print("Connection opened, sending request headers")
    for (k, v) in conn.request.headers.pairs() do
      conn.send_text(k + ": " + v)
    end

  fun ref closed(conn: WebSocketConnection ref) =>
    env.out.print("Connection closed")
