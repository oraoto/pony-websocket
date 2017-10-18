use "net"

actor WebSocketConnection
  let _tcp: TCPConnection
  var closed: Bool = false

  new create(tcp: TCPConnection) =>
    _tcp = tcp

  be send_text(text: String val) =>
    if not closed then
      _tcp.writev(Frame.text(text).build())
    end

  be send_binary(data: Array[U8] val) =>
    if not closed then
      _tcp.writev(Frame.binary(data).build())
    end

  be send_ping() =>
    if not closed then
      _tcp.writev(Frame.ping("").build())
    end

  be send_pong() =>
    if not closed then
      _tcp.writev(Frame.pong("").build())
    end

  be send_close() =>
    if not closed then
      _tcp.writev(Frame.close().build())
      _tcp.dispose()
    end
