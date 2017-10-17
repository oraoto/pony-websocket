use "net"

actor WebSocketConnection
  let _tcp: TCPConnection
  let _notify: WebSocketConnectionNotify

  new create(tcp: TCPConnection, notify: WebSocketConnectionNotify iso) =>
    _tcp = tcp
    _notify = consume notify

  be send_text(data: Array[U8] val) =>
    None

  be send_binary(data: Array[U8] val) =>
    None

  be close() =>
    None

  be received(data: Array[U8] iso) =>
    _notify.text_received(this, consume data)
