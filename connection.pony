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

  be send_ping(data: Array[U8] val) =>
    if not closed then
      _tcp.writev(Frame.ping(data).build())
    end

  be send_pong(data: Array[U8] val) =>
    if not closed then
      _tcp.writev(Frame.pong(data).build())
    end

  be send_close(code: U16) =>
    if not closed then
      _tcp.writev(Frame.close(code).build())
      _tcp.dispose()
    end
