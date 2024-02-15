use "net"
use "buffered"
use "net_ssl"

actor WebSocketListener
  let _tcp_listner: TCPListener

  new create(
    auth: TCPListenAuth,
    notify: WebSocketListenNotify iso,
    host: String,
    service: String,
    limit: USize val = 0,
    read_buffer_size: USize val = 16384,
    yield_after_reading: USize val = 16384,
    yield_after_writing: USize val = 16384,
    ssl_context: (SSLContext | None) = None
    )
  =>
    _tcp_listner = TCPListener(auth,
      recover _TCPListenNotify(consume notify, ssl_context) end,
      host,
      service,
      limit,
      read_buffer_size,
      yield_after_reading,
      yield_after_writing)

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
      SSLConnection(WebsocketTCPConnectionNotify(consume n), consume ssl)
    else
      WebsocketTCPConnectionNotify(consume n)
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

class WebsocketTCPConnectionNotify is TCPConnectionNotify
  var _notify: (WebSocketConnectionNotify iso | None)
  var _http_parser: _HttpParser ref = _HttpParser
  let _buffer: Reader ref = Reader
  var _state: State
  var _frame_decoder: _FrameDecoder ref = _FrameDecoder
  var _connection: (WebSocketConnection | None) = None

  new iso create(notify: WebSocketConnectionNotify iso) =>
    _state = _Connecting
    _notify = consume notify

  new iso open(notify: WebSocketConnectionNotify iso) =>
    _state = _Open
    _notify = consume notify
    _connection = None


  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    // Should not handle any data when connection closed or error occured
    if (_state is _Error) or (_state is _Closed) then
      return false
    end

    _buffer.append(consume data)

    try
      match _state
      | _Connecting =>
          while (_buffer.size() > 0) do
            _handle_handshake(conn, _buffer)
          end
      | _Open if _connection is None =>
        // initialize the connection first
        match _notify = None
        | let ws_notify: WebSocketConnectionNotify iso =>
          _connection = WebSocketConnection(conn, consume ws_notify, HandshakeRequest.create())
        else
          error
        end
        _handle_frame(conn, _buffer)?
      | _Open =>
        _handle_frame(conn, _buffer)?
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
      | let req: HandshakeRequest val =>
        let rep = req._handshake()?
        conn.write(rep)
        _state = _Open
        // Create connection
        match (_notify = None, _connection)
        | (let n: WebSocketConnectionNotify iso, None) =>
          _connection = WebSocketConnection(conn, consume n, req)
        end
        conn.expect(2)? // expect minimal header
      end
    else
      conn.write("HTTP/1.1 400 BadRequest\r\n\r\n")
      conn.dispose()
    end

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref)? =>
    // as we do not always control the exact size we get in the next call (e.g.
    // when the TCPConnection has been opened by another program) there might be
    // some leftover data. We try to decode a frame as long as we have enough
    // data
    var expect: USize = 1
    while expect <= buffer.size() do
      let frame = _frame_decoder.decode(_buffer)?
      match frame
      | let f: Frame val =>
        match (_connection, f.opcode)
        | (None, Text) => error
        | (let c : WebSocketConnection, Text)   => c._text_received(f.data as String)
        | (let c : WebSocketConnection, Binary) => c._binary_received(f.data as Array[U8] val)
        | (let c : WebSocketConnection, Ping)   => c._send_pong(f.data as Array[U8] val)
        | (let c : WebSocketConnection, Close)  => c._close(1000)
        end
        expect = 2 // expect next header
      | let n: USize =>
          // need more data to parse a frame
          expect = n
      end
    end
    // notice: if n > read_buffer_size, connection will be closed
    conn.expect(expect - buffer.size())?

  fun ref closed(conn: TCPConnection ref) =>
    // When TCP connection is closed, enter CLOSED state.
    // See https://tools.ietf.org/html/rfc6455#section-7.1.4
    _state = _Closed
    match _connection
    | let c: WebSocketConnection =>
      c._notify_closed()
    end
