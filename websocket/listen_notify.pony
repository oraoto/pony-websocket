interface WebSocketListenNotify

  fun ref listening() => None

  fun ref not_listening() => None

  fun ref connected(): WebSocketConnectionNotify iso^