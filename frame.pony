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

class trn Frame
  var opcode: Opcode

  // Unmasked data.
  var data: (String val | Array[U8 val] val)

  // RFC-6455: A client MUST mask all frames that it.
  // RFC-6455: A server MUST NOT mask any frames that it sends to the client.
  let maskeded: Bool

  new iso create(opcode': Opcode, data':  (String val | Array[U8 val] iso), masked': Bool = false) =>
    opcode = opcode'
    data = consume data'
    maskeded = masked'

  // Create an Text frame
  new iso text(data': String = "", masked': Bool = false) =>
    opcode = Text
    data = consume data'
    maskeded = masked'

  // Create an Text frame
  new iso ping(data': Array[U8 val] val, masked': Bool = false) =>
    opcode = Ping
    data = data'
    maskeded = masked'

  new iso pong(data': Array[U8 val] val, masked': Bool = false) =>
    opcode = Pong
    data = data'
    maskeded = masked'

  new iso binary(data': Array[U8 val] val, masked': Bool = false) =>
    opcode = Binary
    data = data'
    maskeded = masked'

  new iso close(code: U16 = 1000, masked': Bool = false) =>
    opcode = Close
    data = [U8.from[U16](code.shr(8)); U8.from[U16](code and 0xFF)]
    maskeded = masked'

  // Build a frame that the server can send to client, data is not masked
  fun val build(): Array[(String val | Array[U8 val] val)] iso^ =>
    let writer: Writer = Writer

    match opcode
    | Text   => writer.u8(0b1000_0001)
    | Binary => writer.u8(0b1000_0010)
    | Ping   => writer.u8(0b1000_1001)
    | Pong   => writer.u8(0b1000_1010)
    | Close =>
      writer.u8(0b1000_1000)
      writer.u8(0x2)      // two bytes for code
      writer.write(data)  // status code
      return writer.done()
    end

    var payload_len = data.size()
    if payload_len < 126 then
      writer.u8(U8.from[USize](payload_len))
    elseif payload_len < 65536 then
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
  var prev_opcode: Opcode = Text
  var opcode : Opcode = Text
  var state: _DecodeState = _ExpectHeader
  var status: U16 = 1000
  var masked: Bool = true
  var mask_key: Array[U8] = mask_key.create(4)
  var _expect: USize = 2
  var _payload_len: USize = 0
  var fin: Bool = true
  var fragmented: Bool = false
  var fragment: Writer = Writer // fragment buffer

  // USize: expect more data
  // Frame: an parsed frame
  fun ref decode(buffer: Reader): (USize | Frame val)? =>
    match state
      | _ExpectHeader => _parse_header(buffer)?
      | _ExpectExtendedPayloadLen16 => _parse_extended_16(buffer)?
      | _ExpectExtendedPayloadLen64 => _parse_extended_64(buffer)?
      | _ExpectMaskKeyAndPayload => _parse_payload(buffer)?
    end

  fun ref _parse_payload(buffer: Reader): (USize| Frame val)? =>
    if masked then
      mask_key = buffer.block(4)?
    end
    var payload: Array[U8 val] iso = buffer.block(_payload_len)?
    state = _ExpectHeader // expect next header

    if masked then
      payload = unmask(consume payload)
    end

    if not ((opcode is Ping) or (opcode is Pong) or (opcode is Close)) then
      if fragmented and (not fin) then
        fragment.write(consume payload)
        return 2
      else
        let size = payload.size() + fragment.size()
        let fragment_data: Array[ByteSeq] iso = fragment.done()
        payload = _concat_fragment(consume fragment_data, consume payload, size)
        status = 1000
        fragmented = false
      end
    end

    match opcode
    | Text => Frame.text(String.from_array(consume payload), masked)
    | Binary => Frame.binary(consume payload, masked)
    | Ping =>
      if payload.size() > 125 then
        status = 1002
        error
      else
        opcode = prev_opcode
        Frame.ping(consume payload, masked)
      end
    | Pong =>
      opcode = prev_opcode
      Frame.pong(consume payload, masked)
    | Continuation => 2 // expect next frame
    | Close =>
        if payload.size() >= 2 then
          let code = try U16.from[U8](payload(0)?).shl(8) + U16.from[U8](payload(1)?) else 1000 end
          if (code < 1000) or ((code >= 1004) and (code <= 1006)) or ((code >= 1014) and (code <= 2999)) or (code > 4999) then
            status = 1002
            error
          else
            Frame.close(code, masked)
          end
        else
          Frame.close(1000, masked)
        end
    end

  fun ref _concat_fragment(fragment_data: Array[ByteSeq] iso, payload: Array[U8 val] iso, size: USize): Array[U8 val] iso^ =>
    let new_p : Array[U8 val] iso = recover Array[U8].create(payload.size()) end
    for f in (consume fragment_data).values() do
      match f
      | let u: Array[U8] val =>
        new_p.concat(recover u.values() end)
      end
    end
    for x in (consume payload).values() do
      new_p.push(x)
    end
    new_p

  fun ref _parse_header(buffer: Reader): USize? =>
    status = 1000

    let first_byte = buffer.u8()?
    fin = first_byte.shr(7) == 0b1

    // RSV must be 0
    let rsv = (first_byte and 0b0111_0000).shr(4)
    if rsv != 0 then
      status = 1002
      error
    end

    let current_op = match first_byte and 0b00001111
    | Continuation() => Continuation
    | Text()    => Text
    | Binary()  => Binary
    | Ping()    => Ping
    | Pong()    => Pong
    | Close()   => Close
    | let other: U8 => // Reserved Opcode
      status = 1002
      error
    end

    // Save prev_opcode, recover in _parse_payload
    if (current_op is Ping) or (current_op is Pong) then
      prev_opcode = opcode
      opcode = current_op
    end


    if fin and (not (current_op is Continuation)) then // FIN = 1 & OP != 0
      if fragmented and ((not(current_op is Close)) and (not (current_op is Ping)) and (not (current_op is Ping))) then
        status = 1002 // fragmented
        error
      else
        opcode = current_op // normal frame
      end
    end

    if fin and (current_op is Continuation) and (not fragmented) then // FIN = 1 & OP == 0
      status = 1002
      error
    end

    if not fin then
      match current_op
      | Close =>  // close must be fin?
        status = 1052
        error
      | Ping => // control message MUST NOT be fragmented
        status = 1001
        error
      | Pong => // control message MUST NOT be fragmented
        status = 1001
        error
      | Continuation =>
          if not fragmented then
            status = 1001
            error
          end
      | let other: Opcode => // Start an fragmented message
          if not fragmented then
            fragmented = true
            opcode = current_op
          end
      end
    end

    let second_byte = buffer.u8()?
    masked = second_byte.shr(7) == 0b1
    let mask_bytes : USize = if masked then 4 else 0 end

    let payload_len = second_byte and 0b01111111

    match current_op
    | Close => if (payload_len == 1) or (payload_len > 125) then // 0 or >= 2
        status = 1002
        error
      end
    end

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
    _payload_len + if masked then 4 else 0 end

  fun ref _parse_extended_64(buffer: Reader): USize? =>
    let payload_len = buffer.u64_be()?
    state = _ExpectMaskKeyAndPayload
    _payload_len = USize.from[U64](payload_len)
    _payload_len + if masked then 4 else 0 end


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

