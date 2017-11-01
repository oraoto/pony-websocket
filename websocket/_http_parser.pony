use "buffered"
use "collections"

primitive _ExpectRequest
primitive _ExpectHeaders
primitive _ExpectError

type _ParserState is (_ExpectRequest | _ExpectHeaders | _ExpectError)

class _HttpParser
  """
  A cutdown version of net/http/_http_parser, just parse request line and headers.
  """

  var _request: _HandshakeRequest = _HandshakeRequest
  var _state: _ParserState = _ExpectRequest

  fun ref parse(buffer: Reader ref): (_HandshakeRequest | None)? =>
  """
    Return an _HandshakeRequest on success.
    Return None for more data.
  """
    match _state
    | _ExpectRequest => _parse_request(buffer)?
    | _ExpectHeaders => _parse_headers(buffer)?
    end

  fun ref _parse_request(buffer: Reader): None? =>
  """
  Parse request-line: "<Method> <URL> <Proto>"
  """
    try
      let line = buffer.line()?
      try
        let method_end = line.find(" ")?
        _request.method = line.substring(0, method_end)
        let url_end = line.find(" ", method_end + 1)?
        _request.resource = line.substring(method_end + 1, url_end)
        _state = _ExpectHeaders
      else
        _state = _ExpectError
      end
    else
      return None // expect more data for a line
    end

    if _state is _ExpectError then error end // Not an valid request-line

  fun ref _parse_headers(buffer: Reader): (_HandshakeRequest ref | None) ? =>
    while true do
      try
        let line = buffer.line()?
        if line.size() == 0 then
          return _request // Finish parsing
        else
          try
            _process_header(line)?
          else
            _state = _ExpectError
            break
          end
        end
      else
        return None
      end
    end

    if _state is _ExpectError then error end

  fun ref _process_header(line: String) ? =>
    let i = line.find(":")?
    let key = line.substring(0, i)
    key.strip()
    key.lower_in_place()
    let key2: String val = consume key
    let value = line.substring(i + 1)
    value.strip()
    let value2: String val = consume value
    _request.headers(key2) = value2
