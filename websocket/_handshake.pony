use "collections"
use "encode/base64"
use "crypto"

class _HandshakeRequest
  var method: String = ""
  var resource: String = ""
  let headers: Map[String, String] = headers.create(32)

  fun handshake(): String? =>
    try
      let version = headers("sec-websocket-version")?
      let key = headers("sec-websocket-key")?
      let upgrade = headers("upgrade")?
      let connection = headers("connection")?

      if version.lower() != "13" then error end
      if upgrade.lower() != "websocket" then error end
      if connection.lower() != "upgrade" then error end
      response(_handshake(key))
    else
      error
    end

  fun response(key: String): String =>
    "HTTP/1.1 101 Switching Protocols\r\n"
      + "Upgrade: websocket\r\n"
      + "Connection: Upgrade\r\n"
      + "Sec-WebSocket-Accept:" + key
      + "\r\n\r\n"

  fun _handshake(key:String): String =>
    let c = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let digest = Digest.sha1()
    try
      digest.append(c)?
    end
    let d = digest.final()
    Base64.encode(d)
