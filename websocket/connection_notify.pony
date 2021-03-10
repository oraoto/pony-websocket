interface WebSocketConnectionNotify

  fun ref opened(conn: WebSocketConnection ref) =>
    None

  fun ref closed(conn: WebSocketConnection ref) =>
    None

  fun ref text_received(conn: WebSocketConnection ref, text: String): None =>
    None

  fun ref binary_received(
    conn: WebSocketConnection ref,
    data: Array[U8 val] val): None => None
