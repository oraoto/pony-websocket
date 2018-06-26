use "net"

actor WebSocketConnection
  """
  A wrapper around a TCP connection, provides data-sending functionality.
  """

  let _notify: WebSocketConnectionNotify
  let _tcp: TCPConnection
  var _closed: Bool = false
  let request: HandshakeRequest val

  new create(
    tcp: TCPConnection,
    notify: WebSocketConnectionNotify iso,
    request': HandshakeRequest val)
  =>
    _notify = consume notify
    _tcp = tcp
    request = request'
    _notify.opened(this)

  fun send_text(text: String val) =>
    """
    Send text data (without fragmentation), text must be encoded in utf-8.
    """
    if not _closed then
      _tcp.writev(Frame.text(text).build())
    end

  be send_text_be(text: String val) =>
    send_text(text)

  fun send_binary(data: Array[U8] val) =>
    """
    Send binary data (without fragmentation)
    """
    if not _closed then
      _tcp.writev(Frame.binary(data).build())
    end

  be send_binary_be(data: Array[U8] val) =>
    send_binary(data)

  fun ref close(code: U16 = 1000) =>
    """
    Initiate closure, all data sending is ignored after this call.
    """
    if not _closed then
      _tcp.writev(Frame.close(code).build())
      _closed = true
    end

  be close_be(code: U16 = 1000) =>
    close(code)

  be _send_ping(data: Array[U8] val = []) =>
    """
    Send a ping frame.
    """
    if not _closed then
      _tcp.writev(Frame.ping(data).build())
    end

  be _send_pong(data: Array[U8] val) =>
    """
    Send a pong frame.
    """
    if not _closed then
      _tcp.writev(Frame.pong(data).build())
    end

  be _close(code: U16 = 100) =>
    """
    Send a close frame and close the TCP connection, all data sending is
    ignored after this call.
    On client-initiated closure, send a close frame and close the connection.
    On server-initiated closure, close the connection without sending another
    close frame.
    """
    if not _closed then
      _tcp.writev(Frame.close(code).build())
      _closed = true
    end
    _tcp.dispose()

  be _text_received(text: String) =>
    _notify.text_received(this, text)

  be _binary_received(data: Array[U8] val) =>
    _notify.binary_received(this, data)

  be _notify_closed() =>
    _notify.closed(this)
