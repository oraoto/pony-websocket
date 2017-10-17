use "buffered"

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

class _FrameDecoder
  var opcode : Opcode = Text
  var payload_type: PayloadType = ExtendedPayload0
  var data: String = ""
  var is_fin: Bool = true

  fun ref decode(buffer: Reader): Frame? =>
    try
      let first_byte = buffer.u8()?

      is_fin = first_byte.shr(7) == 0b1

      match first_byte and 0b00001111
      | Text() => opcode = Text
      | Binary() => opcode = Binary
      end

      let second_byte = buffer.u8()?

      let is_mask = second_byte.shr(7) == 0b1
      let payload_len = second_byte and 0b01111111

          if is_mask then
        var mask_key = buffer.block(4)?
        var payload = buffer.block(USize.from[U8](payload_len))?
        let p = unmask(consume mask_key, consume payload)
        Frame.text(String.from_array(consume p))
      else
        var payload = buffer.block(USize.from[U8](payload_len))?
        Frame.text(String.from_array(consume payload))
      end


    else
      error
    end


  fun unmask(mask_key: Array[U8 val] iso, payload: Array[U8 val] iso): Array[U8 val] iso^ =>
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

