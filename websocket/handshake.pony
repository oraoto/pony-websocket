use "collections"
use "encode/base64"
use "crypto"

class HandshakeRequest
  var method: String = ""
  var resource: String = ""
  let headers: Map[String, String] = headers.create(32)

  fun _handshake(): String ? =>
    try
      let version = headers("sec-websocket-version")?
      let key = headers("sec-websocket-key")?
      let upgrade = headers("upgrade")?
      let connection = headers("connection")?

      if version.lower() != "13" then error end
      if upgrade.lower() != "websocket" then error end
      var conn_upgrade = false
      for s in connection.split_by(",").values() do
        if s.lower().>strip(" ") == "upgrade" then
          conn_upgrade = true
          break
        end
      end
      if not conn_upgrade then error end

      _response(_accept_key(key))
    else
      error
    end

  fun _response(key: String): String =>
    "HTTP/1.1 101 Switching Protocols\r\n"
      + "Upgrade: websocket\r\n"
      + "Connection: Upgrade\r\n"
      + "Sec-WebSocket-Accept:" + key
      + "\r\n\r\n"

  fun _accept_key(key: String): String =>
    let c = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let digest = Digest.sha1()
    try
      digest.append(consume c)?
    end
    let d = digest.final()
    Base64.encode(d)

  fun ref _set_header(key: String, value: String) =>
    headers(key) = value
