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
  var _connecion: (WebSocketConnection | None) = None
  var _http_parser: _HttpParser = _HttpParser
  let _buffer: Reader = Reader
  var _state: State = _Connecting
  var _frame_decoder: _FrameDecoder = _FrameDecoder

  new iso create(notify: WebSocketConnectionNotify iso) =>
    _notify = consume notify

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    _buffer.append(consume data)

    match _state
    | _Connecting =>
      try
        match _parse_handshake_request()?
        | None => _state = _Error
        | let req: _HandshakeRequest =>
          try
            let rep = req.handshake()?
            conn.write(rep)
            _state = _Open
          else
            _state = _Open
          end
        end
      end
    | _Open =>
      try
        let frame = _frame_decoder.decode(_buffer)?
      end
      true
    | _Closing => @printf[I32]("Closing: parse data to frame pass and notify\n".cstring())
      true
    | _Closed => @printf[I32]("Closed".cstring())
      true
    | _Error => @printf[I32]("Error".cstring())
      false
    end

    match _state
    | _Error  => false
    | _Closed  => false
    | _Open => true
    | _Closing => true
    | _Connecting => true
    end

  fun ref _parse_handshake_request(): (None| _HandshakeRequest ref)? =>
    try
      _http_parser.parse(_buffer)?
      _http_parser.ready()
    else
      error
    end

    // match _state
    //   | ExpectHandshake => true
    //   | Handshaked =>
    //     let dummy_notify = DummyWebSocketConnectionNotify
    //     _connecion = WebSocketConnection(conn, _notify = consume dummy_notify)
    //     try
    //       (_connecion as WebSocketConnection).received(consume data)
    //     end
    //     true
    // end
    // true

  fun ref connect_failed(conn: TCPConnection ref) => None

