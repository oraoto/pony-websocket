interface WebSocketConnectionNotify

  fun ref opened(conn: WebSocketConnection tag) =>
    None

  fun ref closed(conn: WebSocketConnection tag) =>
    None

  fun ref text_received(conn: WebSocketConnection tag, text: String): None =>
    None

  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8 val] val): None =>
    None
