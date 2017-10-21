# pony-websocket

WebSocket server for pony

It's RFC6455 conformant, see [test report](https://oraoto.github.io/pony-websocket/).

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* Update your `bundle.json`

```json
{
  "type": "github",
  "repo": "oraoto/pony-websocket"
}
```

* `stable fetch` to fetch your dependencies
* `use "websocket"` to include this package
* `stable env ponyc` to compile your application
