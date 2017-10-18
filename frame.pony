use "buffered"
use "net"
use "random"

primitive Continuation  fun apply(): U8 => 0x00
primitive Text          fun apply(): U8 => 0x01
primitive Binary        fun apply(): U8 => 0x02
primitive Close         fun apply(): U8 => 0x08
primitive Ping          fun apply(): U8 => 0x09
primitive Pong          fun apply(): U8 => 0x0A

type Opcode is (Continuation | Text | Binary | Ping | Pong | Close)

primitive ExtendedPayload0  fun apply(): U8 => 0
primitive ExtendedPayload16 fun apply(): U8 => 16
primitive ExtendedPayload64 fun apply(): U8 => 64

type PayloadType is (ExtendedPayload0 | ExtendedPayload16 | ExtendedPayload64)

class trn Frame
  var opcode: Opcode

  // Unmasked data.
  var data: (String val | Array[U8 val] val)

  // RFC-6455: A client MUST mask all frames that it.
  // RFC-6455: A server MUST NOT mask any frames that it sends to the client.
  let is_masked: Bool

  new iso create(opcode': Opcode, data':  (String val | Array[U8 val] iso), is_mask': Bool = false) =>
    opcode = opcode'
    data = consume data'
    is_masked = is_mask'

  // Create an Text frame
  new iso text(data': String = "", is_mask': Bool = false) =>
    opcode = Text
    data = consume data'
    is_masked = is_mask'

  // Create an Text frame
  new iso ping(data': String = "", is_mask': Bool = false) =>
    opcode = Ping
    data = data'
    is_masked = is_mask'

  new iso pong(data': String = "", is_mask': Bool = false) =>
    opcode = Pong
    data = data'
    is_masked = is_mask'

  new iso binary(data': Array[U8 val] val, is_mask': Bool = false) =>
    opcode = Binary
    data = data'
    is_masked = is_mask'

  new iso close(is_mask': Bool = false) =>
    opcode = Close
    data = ""
    is_masked = is_mask'

  // Build a frame that the server can send to client, data is not masked
  fun val build(): Array[(String val | Array[U8 val] val)] iso^ =>
    let writer: Writer = Writer

    match opcode
    | Text   => writer.u8(0b1000_0001)
    | Binary => writer.u8(0b1000_0010)
    | Ping   =>
      writer.u8(0b1000_1001)
      writer.u8(0)
      return writer.done()
    | Pong   =>
      writer.u8(0b1000_1010)
      writer.u8(0)
      return writer.done()
    end

    var payload_len = data.size()
    if payload_len < 126 then
      writer.u8(U8.from[USize](payload_len))
    elseif payload_len < 65535 then
      writer.u8(126)
      writer.u16_be(U16.from[USize](payload_len))
    else
      writer.u8(127)
      writer.u64_be(U64.from[USize](payload_len))
    end
    writer.write(data)
    writer.done()

primitive _ExpectHeader
primitive _ExpectExtendedPayloadLen16
primitive _ExpectExtendedPayloadLen64
primitive _ExpectMaskKeyAndPayload

type _DecodeState is (
    _ExpectHeader
  | _ExpectExtendedPayloadLen16
  | _ExpectExtendedPayloadLen64
  | _ExpectMaskKeyAndPayload)


class _FrameDecoder
  var opcode : Opcode = Text
  var payload_type: PayloadType = ExtendedPayload0
  var data: String = ""
  var is_fin: Bool = true
  var state: _DecodeState = _ExpectHeader
  var is_mask: Bool = true
  var mask_key: Array[U8] = mask_key.create(4)
  var _expect: USize = 2
  var _payload_len: USize = 0

  fun ref decode(buffer: Reader): (USize | Frame val)? =>
    match state
      | _ExpectHeader => _parse_header(buffer)?
      | _ExpectExtendedPayloadLen16 => _parse_extended_16(buffer)?
      | _ExpectExtendedPayloadLen64 => _parse_extended_64(buffer)?
      | _ExpectMaskKeyAndPayload => _parse_payload(buffer)?
    end

  fun ref _parse_payload(buffer: Reader): (USize| Frame val)? =>
    if is_mask then
      mask_key = buffer.block(4)?
    end
    var payload = buffer.block(_payload_len)?
    state = _ExpectHeader // expect next header

    if is_mask then
      payload = unmask(consume payload)
    end

    match opcode
    | Text => Frame.text(String.from_array(consume payload), is_mask)
    | Binary => Frame.binary(consume payload, is_mask)
    | Ping => Frame.ping(String.from_array(consume payload), is_mask)
    | Pong => Frame.pong(String.from_array(consume payload), is_mask)
    | Continuation => error
    | Close => Frame.close(is_mask)
    end

  fun ref _parse_header(buffer: Reader): USize? =>
    let first_byte = buffer.u8()?
    is_fin = first_byte.shr(7) == 0b1

    match first_byte and 0b00001111
    | Text()    => opcode = Text
    | Binary()  => opcode = Binary
    | Ping()    => opcode = Ping
    | Pong()    => opcode = Pong
    | Close()   => opcode = Close
    end

    let second_byte = buffer.u8()?
    is_mask = second_byte.shr(7) == 0b1
    let mask_bytes : USize = if is_mask then 4 else 0 end

    let payload_len = second_byte and 0b01111111

    if payload_len == 126 then
      state = _ExpectExtendedPayloadLen16
      return 2
    elseif payload_len == 127 then
      state = _ExpectExtendedPayloadLen64
      return 8
    else
      state = _ExpectMaskKeyAndPayload
      _payload_len = USize.from[U8](payload_len)
      _expect = _payload_len + mask_bytes
      return _expect
    end

  fun ref _parse_extended_16(buffer: Reader): USize? =>
    let payload_len = buffer.u16_be()?
    state = _ExpectMaskKeyAndPayload
    _payload_len = USize.from[U16](payload_len)
    _payload_len + if is_mask then 4 else 0 end

  fun ref _parse_extended_64(buffer: Reader): USize? =>
    let payload_len = buffer.u64_be()?
    state = _ExpectMaskKeyAndPayload
    _payload_len = USize.from[U64](payload_len)
    _payload_len + if is_mask then 4 else 0 end


  fun unmask(payload: Array[U8 val] iso): Array[U8 val] iso^ =>
    let p = consume payload
    let size = p.size()
    var i: USize = 0
    try
      while i < size do
        p(i)? = p(i)? xor mask_key(i % 4)?
        i = i + 1
      end
    end
    p

