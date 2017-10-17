use "buffered"
use "net"

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

class Frame
  var data: String
  var opcode: Opcode
  var payload_type: PayloadType

  new iso text(data': String = "") =>
      data = data'
      opcode = Text
      payload_type =
        if data.size() <= 125 then
          ExtendedPayload0 else if data.size() <= 65535 then
          ExtendedPayload16 else
          ExtendedPayload64 end end


  // fun decode() : Frame =>
  //   let writer: Writer = Writer
  //   match opcode
  //   | Text =>   writer.u8(0b10000001)
  //   | Binary => writer.u8(0b10000010)
  //   | Pong =>   writer.u8(0b10001010)
  //   end


primitive _ExpectHeader
primitive _ExpectExtendedPayloadLen16
primitive _ExpectExtendedPayloadLen64
primitive _ExpectMaskKey
primitive _ExpectPayload

type _DecodeState is (
    _ExpectHeader
  | _ExpectExtendedPayloadLen16 // include mask key
  | _ExpectExtendedPayloadLen64
  | _ExpectPayload)


class _FrameDecoder
  var opcode : Opcode = Text
  var payload_type: PayloadType = ExtendedPayload0
  var data: String = ""
  var is_fin: Bool = true
  var conn: TCPConnection ref
  var state: _DecodeState = _ExpectHeader
  var is_mask: Bool = true
  var mask_key: Array[U8] = mask_key.create(4)
  var _expect: USize = 2
  var _payload_len: USize = 0

  new create(conn': TCPConnection ref) =>
    conn = conn'


  fun ref decode(buffer: Reader): (USize | Frame)? =>
    match state
      | _ExpectHeader => _parse_header(buffer)?
      | _ExpectExtendedPayloadLen16 => _parse_extended_16(buffer)?
      | _ExpectExtendedPayloadLen64 => _parse_extended_64(buffer)?
      | _ExpectPayload => _parse_payload(buffer)?
    end

  fun ref _parse_payload(buffer: Reader): (USize| Frame)? =>
    if is_mask then
      mask_key = buffer.block(4)?
    end
    var payload = buffer.block(_payload_len)?
    state = _ExpectHeader
    if is_mask then
      let p = unmask(consume payload)
      Frame.text(String.from_array(consume p))
    else
      Frame.text(String.from_array(consume payload))
    end


  fun ref _parse_header(buffer: Reader): USize? =>
    let first_byte = buffer.u8()?
    is_fin = first_byte.shr(7) == 0b1

    match first_byte and 0b00001111
    | Text() => opcode = Text
    | Binary() => opcode = Binary
    end

    let second_byte = buffer.u8()?
    is_mask = second_byte.shr(7) == 0b1
    let mask_bytes : USize = if is_mask then 4 else 0 end

    let payload_len = second_byte and 0b01111111
    @printf[I32]("payload_len ".cstring())
    @printf[I32](payload_len.string().cstring())
    @printf[I32]("\n".cstring())

    if payload_len == 126 then
      state = _ExpectExtendedPayloadLen16
      return 2
    elseif payload_len == 127 then
      state = _ExpectExtendedPayloadLen64
      return 4
    else
      state = _ExpectPayload
      _payload_len = USize.from[U8](payload_len)
      _expect = _payload_len + mask_bytes
      return _expect
    end

  fun ref _parse_extended_16(buffer: Reader): USize? =>
    @printf[I32]("extended_16\n".cstring())
    let payload_len = buffer.u16_be()?

    state = _ExpectPayload
    _payload_len = USize.from[U16](payload_len)
    _payload_len + if is_mask then 4 else 0 end

  fun ref _parse_extended_64(buffer: Reader): USize? =>
    @printf[I32]("extended_64\n".cstring())
    let payload_len = buffer.u64_be()?
    if is_mask then
      mask_key = buffer.block(4)?
    end
    state = _ExpectPayload
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

