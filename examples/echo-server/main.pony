use "package:../../websocket"
use "net"

class EchoConnectionNotify is TCPConnectionNotify

  var ws: WebSocket = WebSocket

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    match ws.received(conn, consume data)
      | let msg: BinaryMessage => ws.send(conn, msg)
      | let msg: TextMessage   => ws.send(conn, msg)
    end
    true

  fun ref closed(conn: TCPConnection ref) => None

  fun ref connect_failed(conn: TCPConnection ref) => None

class EchoListenNotify is TCPListenNotify
  fun ref connected(listen: TCPListener ref): EchoConnectionNotify iso^ =>
    EchoConnectionNotify

  fun ref not_listening(listen: TCPListener ref) => None

actor Main
  new create(env: Env) =>
    try
      let listener = TCPListener(env.root as AmbientAuth, EchoListenNotify, "0.0.0.0", "8989")
    end
