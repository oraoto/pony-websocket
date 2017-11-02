use "net"

actor WebSocketConnection
  """
  A wrapper around a TCP connection, provides data-sending functionality.
  """

  let _tcp: TCPConnection
  var closed: Bool = false

  new create(tcp: TCPConnection) =>
    _tcp = tcp

  be send_text(text: String val) =>
    """
    Send text data (without fragmentation), text must be encoded in utf-8.
    """
    if not closed then
      _tcp.writev(Frame.text(text).build())
    end

  be send_binary(data: Array[U8] val) =>
    """
    Send binary data (without fragmentation)
    """
    if not closed then
      _tcp.writev(Frame.binary(data).build())
    end

  be close(code: U16 = 1000) =>
    """
    Initiate closure, all data sending are ignored after this call.
    """
    if not closed then
      _tcp.writev(Frame.close(code).build())
      closed = true
    end

  be _send_ping(data: Array[U8] val = []) =>
    """
    Send a ping frame.
    """
    if not closed then
      _tcp.writev(Frame.ping(data).build())
    end

  be _send_pong(data: Array[U8] val) =>
    """
    Send a pong frame.
    """
    if not closed then
      _tcp.writev(Frame.pong(data).build())
    end

  be _close(code: U16 = 100) =>
    """
    Send a close frame and close the TCP connection, all data sending are
    ignored after this call.
    On client-initiated closure, send a close frame and close the connection.
    On server-initiated closure, close the connection without sending another
    close frame.
    """
    if not closed then
      _tcp.writev(Frame.close(code).build())
      closed = true
    end
    _tcp.dispose()
