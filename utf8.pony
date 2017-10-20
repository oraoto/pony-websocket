
primitive UTF8

  fun validate(data: Array[U8 val] iso, start_index: USize): Array[U8 val] iso^? =>
    let buf = consume data
    let len = buf.size()
    var i = start_index
    var valid: Bool = true

    // TODO: multiline array
    let char_width: Array[U8] = [
      1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1; 0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0; 0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0; 0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0; 0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0; 0;0;2;2;2;2;2;2;2;2;2;2;2;2;2;2; 2;2;2;2;2;2;2;2;2;2;2;2;2;2;2;2; 3;3;3;3;3;3;3;3;3;3;3;3;3;3;3;3;4;4;4;4;4;0;0;0;0;0;0;0;0;0;0;0
    ]

    while i < len do
      let first = buf(i)?
      if first > 128 then
        let w = char_width(USize.from[U8](first))?
        match w
        | 2 =>
          if ((i + 1) == len) or _cont(buf(i + 1)?) then
            valid = false
            break
          else
            i = i + 2
          end
        | 3 =>
          if ((i + 2) >= len) then
            valid = false
            break
          end
          if _cont(buf(i + 2)?) then
            valid = false
            break
          end

          let b2 = buf(i + 1)?
          if not (
               ((first == 0xe0)              and _in_range(b2, 0xA0, 0xbf))
            or (_in_range(first, 0xe1, 0xec) and _in_range(b2, 0x80, 0xbf))
            or ((first == 0xed)              and _in_range(b2, 0x80, 0x9f))
            or (_in_range(first, 0xee, 0xef) and _in_range(b2, 0x80, 0xbf))
            ) then
            valid = false
            break
          end
          i = i + 3
        | 4 =>
          if ((i + 3) >= len) then
            valid = false
            break
          end
          if _cont(buf(i + 2)?) or _cont(buf(i + 3)?) then
            valid = false
            break
          end

          let b2 = buf(i + 1)?
          if not(
               ((first == 0xf0)              and _in_range(b2, 0x90, 0xbf))
            or (_in_range(first, 0xf1, 0xf3) and _in_range(b2, 0x80, 0xbf))
            or ((first == 0xf4)              and _in_range(b2, 0x80, 0x8f))
          ) then
            valid = false
            break
          end
          i = i + 4

        | let o: U8 =>
          valid = false
          break
        end
      else
        if first == 128 then
          valid = false
          break
        end
        i = i + 1
      end
    end

    if valid then
      buf
    else
      error
    end

  fun _in_range(a: U8, b: U8, c: U8): Bool =>
    (a >= b) and (a <= c)

  fun _cont(a: U8): Bool =>
    (a and (not 0b0011_1111)) != 0b1000_0000