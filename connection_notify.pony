
interface WebSocketConnectionNotify

  fun ref open(conn: WebSocketConnection ref) =>
    None

  fun ref closed(conn: WebSocketConnection ref) =>
    None

  fun ref text_received(conn: WebSocketConnection, data: Array[U8 val] iso) : Bool =>
    true

  fun ref binary_received(conn: WebSocketConnection, data: Array[U8 val] iso, times: USize) : Bool =>
    true

class DummyWebSocketConnectionNotify is WebSocketConnectionNotify
  fun ref connected(conn: WebSocketConnection ref) =>
    None

  fun ref text_received(conn: WebSocketConnection, data: Array[U8 val] iso) : Bool =>
    true
