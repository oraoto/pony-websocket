use "package:../../websocket"
use "collections"

actor Main
  new create(env: Env) =>
    env.out.print("Start server")

    try
      let listener = WebSocketListener(
        env.root as AmbientAuth, BroadcastListenNotify, "127.0.0.1","8989")
    end

actor ConnectionManager
  var _connections: SetIs[WebSocketConnection] =
    SetIs[WebSocketConnection].create()

  be add(conn: WebSocketConnection) =>
    @printf[I32]("Add connection\n".cstring())
    _connections.set(conn)

  be remove(conn: WebSocketConnection) =>
    @printf[I32]("Remove connection\n".cstring())
    _connections.unset(conn)

  be broadcast_text(text: String) =>
    for c in _connections.values() do
      c.send_text(text)
    end

  be broadcast_binary(data: Array[U8] val) =>
    for c in _connections.values() do
      c.send_binary(data)
    end

class BroadcastListenNotify is WebSocketListenNotify
  var _conn_manager: ConnectionManager = ConnectionManager.create()

  fun ref connected(): BroadcastConnectionNotify iso^ =>
    BroadcastConnectionNotify(_conn_manager)

  fun ref not_listening() =>
    @printf[I32]("Failed listening\n".cstring())

class BroadcastConnectionNotify is WebSocketConnectionNotify
  var _conn_manager: ConnectionManager

  new iso create(conn_manager: ConnectionManager) =>
    _conn_manager = conn_manager

  fun ref opened(conn: WebSocketConnection tag) =>
    _conn_manager.add(conn)

  fun ref text_received(conn: WebSocketConnection tag, text: String) =>
    _conn_manager.broadcast_text(text)

  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8] val) =>
    _conn_manager.broadcast_binary(data)

  fun ref closed(conn: WebSocketConnection tag) =>
    _conn_manager.remove(conn)
