/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 22/05/2018
 * Copyright :  S.Hamblett
 */

part of coap;

/// Channel via UDP protocol.
class CoapUDPChannel extends CoapIChannel {
  /// Initialise with a specific address and port
  CoapUDPChannel(this._address, this._port) {
    _socket = CoapNetworkUDP(address, port);
  }

  int _port;

  @override
  int get port => _port;
  CoapInternetAddress _address;

  @override
  CoapInternetAddress get address => _address;
  CoapNetworkUDP _socket;

  typed.Uint8Buffer _buff = typed.Uint8Buffer();

  @override
  void start() {
    _socket.port = _port;
    _socket.address = _address;
    _socket.bind();
    _socket.receive();
  }

  @override
  void stop() {
    _socket.close();
  }

  @override
  Future<void> send(typed.Uint8Buffer data,
      [CoapInternetAddress address]) async {
    if (address != null) {
      final CoapNetworkUDP socket =
          await CoapNetworkManagement.getNetwork(address, _port);
      if (socket?.socket != null) {
        socket.send(data);
      }
    } else {
      if (_socket?.socket != null) {
        _socket.send(data);
      }
    }
  }

  @override
  void receive() {
    final CoapDataReceivedEvent rxEvent =
        CoapDataReceivedEvent(_buff, _address);
    clientEventBus.fire(rxEvent);
    _buff.clear();
  }
}
