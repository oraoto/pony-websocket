
interface WebSocketConnectionNotify

  fun ref opened(conn: WebSocketConnection tag) =>
    None

  fun ref closed() =>
    None

  fun ref text_received(conn: WebSocketConnection tag, text: String) : Bool =>
    true

  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8 val] val) : Bool =>
    true

class DummyWebSocketConnectionNotify is WebSocketConnectionNotify
  fun ref connected(conn: WebSocketConnection ref) =>
    None


