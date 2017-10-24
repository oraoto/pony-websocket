use "buffered"

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
  var fragment_started: Bool = false
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
      payload = _unmask(consume payload)
    end

    if not _is_control(opcode) then
      if fragment_started and (not fin) then
        fragment.write(consume payload)
        return 2 // next header
      else
        // frame completed
        if fragment.size() > 0 then
          let size = payload.size() + fragment.size()
          let fragment_data: Array[ByteSeq] iso = fragment.done()
          payload = _concat_fragment(consume fragment_data, consume payload, size)
        end
        if opcode is Text then
          payload = validate_utf8(consume payload , 0)?
        end
        status = 1000
        fragment_started = false
      end
    end

    match opcode
    | Text =>   Frame.text(String.from_array(consume payload))
    | Binary => Frame.binary(consume payload)
    | Ping =>
      opcode = prev_opcode
      Frame.ping(consume payload)
    | Pong =>
      opcode = prev_opcode
      Frame.pong(consume payload)
    | Continuation => 2 // expect next frame
    | Close =>
        if payload.size() >= 2 then
          payload = validate_utf8(consume payload, 2)?
          let code = try U16.from[U8](payload(0)?).shl(8) + U16.from[U8](payload(1)?) else 1000 end
          if (code < 1000) or ((code >= 1004) and (code <= 1006)) or ((code >= 1014) and (code <= 2999)) or (code > 4999) then
            _throw[Frame val](1002)?
          else
            Frame.close(code)
          end
        else
          Frame.close(1000)
        end
    end

  fun ref validate_utf8(data: Array[U8 val] iso, idx: USize): Array[U8 val] iso^? =>
    try
      UTF8.validate(consume data, idx)?
    else
      status = 1007
      error
    end

  fun ref _concat_fragment(fragment_data: Array[ByteSeq] iso, payload: Array[U8 val] iso, size: USize): Array[U8 val] iso^ =>
    recover
      let new_p = Array[U8].create(size)
      var i: USize = 0
      // var c: USize = 0
      for f in (consume fragment_data).values() do
        match f
        | let u: Array[U8] val =>
          let s = u.size()
          u.copy_to(new_p, 0, i, s)
          i = i + s
          // c = c + 1
        end
      end
      let p: Array[U8 val] val = consume payload
      let s = p.size()
      p.copy_to(new_p, 0, i, s)
      new_p
    end

  fun ref _parse_header(buffer: Reader): USize? =>
    status = 1000

    let first_byte = buffer.u8()?
    fin = first_byte.shr(7) == 0b1

    // RSV must be 0
    let rsv = (first_byte and 0b0111_0000).shr(4)
    if rsv != 0 then _throw[None](1002)? end

    let current_op = match first_byte and 0b00001111
    | Continuation() => Continuation
    | Text()    => Text
    | Binary()  => Binary
    | Ping()    => Ping
    | Pong()    => Pong
    | Close()   => Close
    | let other: U8 => _throw[Opcode](1002)?
    end

    // Save prev_opcode, recover in _parse_payload
    if _is_pingpong(current_op) then
      prev_opcode = opcode
      opcode = current_op
    end

    // A FIN + Continuation when we're not doing fragmentation
    if fin and (current_op is Continuation) and (not fragment_started) then
      _throw[None](1002)?
    end

    if fin and (not (current_op is Continuation)) then // FIN = 1 & OP != 0
      if fragment_started and (not _is_control(current_op)) then
        _throw[None](1002)?
      else
        opcode = current_op
      end
    end

    if not fin then
      if _is_control(current_op) then
        // control frame must be FIN
        _throw[None](1001)?
      elseif (not fragment_started) and (current_op is Continuation) then
        // Continuation when not fragmented
        _throw[None](1001)?
      elseif not fragment_started then
        opcode = current_op
        fragment_started = true
      end
    end

    let second_byte = buffer.u8()?
    masked = second_byte.shr(7) == 0b1
    let payload_len = second_byte and 0b01111111

    // validate control op and payload len
    if _is_control(current_op) then
        if payload_len > 125 then _throw[None](1002)? end
    end
    if (current_op is Close) and (payload_len == 1) then
      _throw[None](1002)?
    end

    // set state and return expect bytes
    if payload_len == 126 then
      state = _ExpectExtendedPayloadLen16
      return 2
    elseif payload_len == 127 then
      state = _ExpectExtendedPayloadLen64
      return 8
    else
      state = _ExpectMaskKeyAndPayload
      _payload_len = USize.from[U8](payload_len)
      _expect = _payload_len + if masked then 4 else 0 end
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

  fun _unmask(payload: Array[U8 val] iso): Array[U8 val] iso^ =>
    let p = consume payload
    let size = p.size()
    var i: USize = 0
    try
      let m1 = mask_key(0)?
      let m2 = mask_key(1)?
      let m3 = mask_key(2)?
      let m4 = mask_key(3)?
      while (i + 4) < size do
        p(i)?     = p(i)?     xor m1
        p(i + 1)? = p(i + 1)? xor m2
        p(i + 2)? = p(i + 2)? xor m3
        p(i + 3)? = p(i + 3)? xor m4
        i = i + 4
      end
      while i < size do
        p(i)? = p(i)? xor mask_key(i % 4)?
        i = i + 1
      end
    end
    p

  fun _is_control(op: Opcode) : Bool =>
    (op is Ping) or (op is Pong) or (op is Close)

  fun _is_pingpong(op: Opcode): Bool =>
    (op is Ping) or (op is Pong)

  fun ref _throw[A](s: U16): A? =>
    status = s
    error