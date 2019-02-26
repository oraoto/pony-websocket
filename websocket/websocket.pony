use "net"
use "buffered"

primitive Opened
primitive Closed
primitive Continue
type TextMessage is String val
type BinaryMessage is Array[U8] val

type Event is (Opened | Closed | Continue | TextMessage | BinaryMessage)

class WebSocket
  var _http_parser: _HttpParser ref = _HttpParser
  let _buffer: Reader ref = Reader
  var _state: State = _Connecting
  var _frame_decoder: _FrameDecoder ref = _FrameDecoder

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) : Event =>
    // Should not handle any data when connection closed
    if (_state is _Closed) then
      return Closed
    end

    _buffer.append(consume data)

    try
      match _state
        | _Connecting => return _handle_handshake(conn, _buffer)
        | _Open => return _handle_frame(conn, _buffer)?
      end
    else
      close(conn, _frame_decoder.status)
    end
    Closed

  fun ref send(conn: TCPConnection ref, msg: (TextMessage | BinaryMessage)) =>
    match msg
      | let m: TextMessage => conn.writev(Frame.text(m).build())
      | let m: BinaryMessage => conn.writev(Frame.binary(m).build())
    end

  fun ref _handle_handshake(conn: TCPConnection ref, buffer: Reader ref) : (Opened val | Closed val | Continue val) =>
    try
      match _http_parser.parse(_buffer)?
      | let req: HandshakeRequest val =>
        let rep = req._handshake()?
        conn.write(rep)
        _state = _Open
        conn.expect(2) // expect minimal header
        return Opened
      end
    else
      conn.write("HTTP/1.1 400 BadRequest\r\n\r\n")
      conn.dispose()
    end
    Continue

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref) : (TextMessage | BinaryMessage | Closed | Continue)? =>
    let frame = _frame_decoder.decode(_buffer)?
    match frame
    | let f: Frame val =>
      match f.opcode
      | Text =>
        conn.expect(2)
        return f.data
      | Binary =>
        conn.expect(2)
        return f.data
      | Ping =>
        _pong(conn, f.data as Array[U8] val)
        conn.expect(2)
        return Continue
      | Close =>
        close(conn, _frame_decoder.status)
        return Closed
      end
      // expect next header
      conn.expect(2)
    | let n: USize =>
      conn.expect(n) // need more data to parse an frame
      return Continue
    end
    Continue

  fun ref _pong(conn: TCPConnection ref, data: Array[U8] val) =>
    conn.writev(Frame.pong(data).build())

  fun ref close(conn: TCPConnection ref, code: U16 = 1000) =>
    if not (_state is _Closed) then
      _state = _Closed
      conn.writev(Frame.close(code).build())
      conn.dispose()
    end
