use "net"
use "buffered"
use "net/ssl"

actor WebSocketListener
  let _tcp_listner: TCPListener

  new create(auth: TCPListenerAuth, notify: WebSocketListenNotify iso, host: String, service: String, ssl_context: (SSLContext | None) = None) =>
    _tcp_listner = TCPListener(auth, recover _TCPListenNotify(consume notify, ssl_context) end, host, service)

class _TCPListenNotify is TCPListenNotify
  var notify: WebSocketListenNotify iso
  let ssl_context: (SSLContext | None)

  new create(notify': WebSocketListenNotify iso, ssl_context': (SSLContext | None) = None) =>
    notify = consume notify'
    ssl_context = ssl_context'

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ ? =>
    let n = notify.connected()
    match ssl_context
    | let ctx: SSLContext =>
      let ssl = ctx.server()?
      SSLConnection(_TCPConnectionNotify(consume n), consume ssl)
    else
      _TCPConnectionNotify(consume n)
    end

  fun ref not_listening(listen: TCPListener ref) =>
    notify.not_listening()

  fun ref listening(listen: TCPListener ref) =>
    notify.listening()

primitive _Open
primitive _Connecting
primitive _Closed
primitive _Error

type State is (_Connecting | _Open | _Closed | _Error)

class _TCPConnectionNotify is TCPConnectionNotify
  var _notify: WebSocketConnectionNotify ref
  var _http_parser: _HttpParser ref = _HttpParser
  let _buffer: Reader ref = Reader
  var _state: State = _Connecting
  var _frame_decoder: _FrameDecoder ref = _FrameDecoder
  var _connection: (WebSocketConnection | None) = None

  new iso create(notify: WebSocketConnectionNotify iso) =>
    _notify = consume notify

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    // Should not handle any data when connection closed or error occured
    if (_state is _Error) or (_state is _Closed) then
      return false
    end

    _buffer.append(consume data)

    try
      match _state
      | _Connecting => _handle_handshake(conn, _buffer)
      | _Open => _handle_frame(conn, _buffer)?
      end
    else
      _state = _Error
    end

    match _state
    | _Error  =>
      match _connection
      | let c: WebSocketConnection =>
        c._close(_frame_decoder.status)
      end
      false
    | _Closed  => false
    | _Open    => true
    | _Connecting => true
    end

  fun ref connect_failed(conn: TCPConnection ref) => None

  fun ref _handle_handshake(conn: TCPConnection ref, buffer: Reader ref) =>
    try
      match _http_parser.parse(_buffer)?
      | let req: _HandshakeRequest =>
        let rep = req.handshake()?
        conn.write(rep)
        _state = _Open
        // 1. Create
        match _connection
        | None =>
          _connection = WebSocketConnection(conn)
        end
        // 2. Notify
        match _connection
        | let c: WebSocketConnection => _notify.opened(c)
        end
        conn.expect(2) // expect minimal header
      end
    else
      conn.write("HTTP/1.1 400 BadRequest\r\n\r\n")
      conn.dispose()
    end

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref)? =>
    let frame = _frame_decoder.decode(_buffer)?
    match frame
    | let f: Frame val =>
      match (_connection, f.opcode)
      | (None, Text) => error
      | (let c : WebSocketConnection, Text)   => _notify.text_received(c, f.data as String)
      | (let c : WebSocketConnection, Binary) => _notify.binary_received(c, f.data as Array[U8] val)
      | (let c : WebSocketConnection, Ping)   => c._send_pong(f.data as Array[U8] val)
      | (let c : WebSocketConnection, Close)  => c._close(1000)
      end
      conn.expect(2) // expect next header
    | let n: USize =>
      conn.expect(n) // need more data to parse an frame
    end

  fun ref closed(conn: TCPConnection ref) =>
    // When TCP connection is closed, enter CLOSED state.
    // See https://tools.ietf.org/html/rfc6455#section-7.1.4
    _state = _Closed
    match _connection
    | let c: WebSocketConnection =>
      _notify.closed(c)
    end
