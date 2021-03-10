use "package:../../websocket"
use "net_ssl"
use "files"

// Put your test cert.pem and key.pem in this directory

actor Main
  new create(env: Env) =>
    env.out.print("Start server")

    try
      let auth = env.root as AmbientAuth
      let ssl_context: SSLContext val = recover
        SSLContext
          .>set_cert(
            FilePath(auth, "./cert.pem")?,
            FilePath(auth, "./key.pem")?)?
      end
      let listener = WebSocketListener(auth, EchoListenNotify,
        "0.0.0.0", "8989", 0, 16384, 16384, 16384, ssl_context)
    else
      env.out.print("Failed to start server")
    end

// Same as echo-server
class EchoListenNotify is WebSocketListenNotify
  fun ref connected(): EchoConnectionNotify iso^ =>
    @printf[I32]("Connected\n".cstring())
    EchoConnectionNotify

  fun ref not_listening() =>
    @printf[I32]("Failed listening\n".cstring())

class EchoConnectionNotify is WebSocketConnectionNotify
  fun ref opened(conn: WebSocketConnection ref) =>
    @printf[I32]("New client connected\n".cstring())

  fun ref text_received(conn: WebSocketConnection ref, text: String) =>
    conn.send_text(text)

  fun ref binary_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
    conn.send_binary(data)

  fun ref closed(conn: WebSocketConnection ref) =>
    @printf[I32]("Connection closed\n".cstring())
