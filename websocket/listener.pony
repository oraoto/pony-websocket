use "net"
use "buffered"

actor WebSocketListener
  let _tcp_listner: TCPListener

  new create(auth: TCPListenerAuth, notify: WebSocketListenNotify iso, host: String, service: String) =>
    _tcp_listner = TCPListener(auth, recover _TCPListenNotify(consume notify) end, host, service)

class _TCPListenNotify is TCPListenNotify
  var notify: WebSocketListenNotify iso

  new create(notify': WebSocketListenNotify iso) =>
    notify = consume notify'

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    let n = notify.connected()
    _TCPConnectionNotify(consume n)

  fun ref not_listening(listen: TCPListener ref) =>
    None

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
  var _connecion: (WebSocketConnection | None) = None

  new iso create(notify: WebSocketConnectionNotify iso) =>
    _notify = consume notify

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    if _state is _Error then
      return false
    end

    _buffer.append(consume data)

    match _connecion
    | None => _connecion = WebSocketConnection(conn)
    end

    try
      match _state
      | _Connecting => _handle_handshake(conn, _buffer)?
      | _Open => _handle_frame(conn, _buffer)?
      end
    else
      _state = _Error
    end

    match _state
    | _Error  =>
      match _connecion
      | let c: WebSocketConnection =>
        c.send_close(_frame_decoder.status)
      end
      _notify.closed()
      false
    | _Closed  => false
    | _Open => true
    | _Connecting => true
    end

  fun ref connect_failed(conn: TCPConnection ref) => None

  fun ref _handle_handshake(conn: TCPConnection ref, buffer: Reader ref) ? =>
    match _http_parser.parse(_buffer)?
    | let req: _HandshakeRequest =>
      let rep = req.handshake()?
      conn.write(rep)
      _state = _Open
      match _connecion
      | let c: WebSocketConnection => _notify.opened(c)
      end
      conn.expect(2) // expect minimal header
    end

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref)? =>
    let frame = _frame_decoder.decode(_buffer)?
    match frame
    | let f: Frame val =>
        match (_connecion, f.opcode)
        | (None, Text) => error
        | (let c : WebSocketConnection, Text)   => _notify.text_received(c, f.data as String)
        | (let c : WebSocketConnection, Binary) => _notify.binary_received(c, f.data as Array[U8] val)
        | (let c : WebSocketConnection, Ping)   =>
          c.send_pong(f.data as Array[U8] val)
          conn.expect(2)
        | (let c : WebSocketConnection, Close)  =>
          _state = _Closed
          c.send_close(1000)
          _notify.closed()
        end
        conn.expect(2) // expect next header
    | let n: USize =>
        conn.expect(n)
    end
