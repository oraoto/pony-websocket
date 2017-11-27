use "net"

interface SimpleWebSocketNotify
  be opened(conn: WebSocketConnection tag) =>
    None

  be closed(conn: WebSocketConnection tag) =>
    None

  be text_received(conn: WebSocketConnection tag, text: String) =>
    None

  be binary_received(conn: WebSocketConnection tag, data: Array[U8 val] val) =>
    None

  be listening() =>
    None

  be not_listening() =>
    None

class SimpleServer is WebSocketListenNotify
  let _notify: SimpleWebSocketNotify tag

  new create(notify: SimpleWebSocketNotify tag) =>
    _notify = notify

  fun ref connected(): _ConnectionNotify iso^ =>
    _ConnectionNotify(_notify)

  fun ref not_listening() =>
    _notify.not_listening()

class _ConnectionNotify is WebSocketConnectionNotify
  let _notify: SimpleWebSocketNotify tag

  new iso create(notify: SimpleWebSocketNotify tag) =>
    _notify = notify

  fun ref opened(conn: WebSocketConnection tag) =>
    _notify.opened(conn)

  fun ref text_received(conn: WebSocketConnection tag, text: String) =>
    _notify.text_received(conn, text)

  fun ref binary_received(conn: WebSocketConnection tag, data: Array[U8] val) =>
    _notify.binary_received(conn, data)

  fun ref closed(conn: WebSocketConnection tag) =>
    _notify.closed(conn)
