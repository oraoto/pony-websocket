use "buffered"
use "collections"

primitive _ExpectRequest
primitive _ExpectHeaders
primitive _ExpectBody
primitive _ExpectReady
primitive _ExpectError

type _ParserState is (_ExpectRequest | _ExpectHeaders | _ExpectReady | _ExpectError)

class _HttpParser
  var _request: _HandshakeRequest = _HandshakeRequest
  var _state: _ParserState = _ExpectRequest

  fun ref parse(buffer: Reader)? =>
    match _state
    | _ExpectRequest => _parse_request(buffer)?
    | _ExpectHeaders => _parse_headers(buffer)?
    end

  fun ready(): (None | this->_HandshakeRequest ref) =>
    if _state is _ExpectReady then _request else None end

  fun ref _parse_request(buffer: Reader) ? =>
    try
      let line = buffer.line()?
      let method_end = line.find(" ")?
      _request.method = line.substring(0, method_end)
      let url_end = line.find(" ", method_end + 1)?
      _request.resource = line.substring(method_end + 1, url_end)
      _state = _ExpectHeaders
      parse(buffer)?
    else
      error
    end

  fun ref _parse_headers(buffer: Reader) ? =>
    while true do
      try
        let line = buffer.line()?
        if line.size() == 0 then
          _state = _ExpectReady
          return None
        else
          try
            _process_header(line)?
          else
            _state = _ExpectError
            return None
          end
        end
      else
        error // can't read line, need more input
      end
    end

  fun ref _process_header(line: String) ? =>
    let i = line.find(":")?
    let key = line.substring(0, i)
    key.strip()
    let key2: String val = consume key
    let value = line.substring(i + 1)
    value.strip()
    let value2: String val = consume value
    _request.headers(key2) = value2
