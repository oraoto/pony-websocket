use "net"
use "buffered"

actor WebSocketListener
  let _tcp_listner: TCPListener

  new create(auth: TCPListenerAuth, notify: WebSocketListenNotify iso, host: String, service: String) =>
    _tcp_listner = TCPListener(auth, recover WSTCPListenNotify(consume notify) end, host, service)

class WSTCPListenNotify is TCPListenNotify
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
primitive _Closing
primitive _Closed
primitive _Error

type State is (_Connecting | _Open | _Closing | _Closed | _Error)

class _TCPConnectionNotify is TCPConnectionNotify
  var _notify: WebSocketConnectionNotify iso
  var _http_parser: _HttpParser ref = _HttpParser
  let _buffer: Reader ref = Reader
  var _state: State = _Connecting
  var _frame_decoder: _FrameDecoder ref = _FrameDecoder
  var _connecion: (WebSocketConnection | None) = None

  new iso create(notify: WebSocketConnectionNotify iso) =>
    _notify = consume notify

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    _buffer.append(consume data)
    match _connecion
    | None =>
      let dummy_notify = DummyWebSocketConnectionNotify
      _connecion = WebSocketConnection(conn, _notify = consume dummy_notify)
    end

    try
      match _state
      | _Connecting => _handle_handshake(conn, _buffer)?
      | _Open => _handle_frame(conn, _buffer)?
      | _Closing => @printf[I32]("Closing: parse data to frame pass and notify\n".cstring())
      | _Closed => @printf[I32]("Closed".cstring())
      | _Error => @printf[I32]("Error state".cstring())
      end
    else
      _state = _Error
    end

    match _state
    | _Error  =>
      // TODO Close Connection
      conn.close()
      false
    | _Closed  => false
    | _Open => true
    | _Closing => true
    | _Connecting => true
    end

  fun ref connect_failed(conn: TCPConnection ref) => None

  fun ref _handle_handshake(conn: TCPConnection ref, buffer: Reader ref) ? =>
    match _http_parser.parse(_buffer)?
    | let req: _HandshakeRequest =>
      let rep = req.handshake()?
      conn.write(rep)
      _state = _Open
      conn.expect(2) // expect minimal header
    end

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref)? =>
    let frame = _frame_decoder.decode(_buffer)?
    match frame
    | let f: Frame =>
        @printf[I32](f.data.cstring())
        conn.expect(2) // expect next header
    | let n: USize =>
        conn.expect(n)
    end
