import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'constants.dart';
import 'pdu_header.dart';
import 'transmitter_pdu.dart';
import 'signal_pdu.dart';
import 'receiver_pdu.dart';
import 'intercom_signal_pdu.dart';
import 'intercom_control_pdu.dart';

class DisNetworkConfig {
  final String localAddress;
  final int port;
  final bool useMulticast;
  final String multicastGroup;
  final String unicastAddress;
  final String? networkInterface;

  const DisNetworkConfig({
    this.localAddress = DisConstants.defaultLocalAddress,
    this.port = DisConstants.defaultPort,
    this.useMulticast = true,
    this.multicastGroup = DisConstants.defaultMulticastGroup,
    this.unicastAddress = DisConstants.defaultBroadcastAddress,
    this.networkInterface,
  });

  Map<String, dynamic> toJson() => {
        'localAddress': localAddress,
        'port': port,
        'useMulticast': useMulticast,
        'multicastGroup': multicastGroup,
        'unicastAddress': unicastAddress,
        'networkInterface': networkInterface,
      };

  factory DisNetworkConfig.fromJson(Map<String, dynamic> json) =>
      DisNetworkConfig(
        localAddress: json['localAddress'] as String? ?? DisConstants.defaultLocalAddress,
        port: (json['port'] as num?)?.toInt() ?? DisConstants.defaultPort,
        useMulticast: json['useMulticast'] as bool? ?? true,
        multicastGroup: json['multicastGroup'] as String? ?? DisConstants.defaultMulticastGroup,
        unicastAddress: json['unicastAddress'] as String? ?? DisConstants.defaultBroadcastAddress,
        networkInterface: json['networkInterface'] as String?,
      );
}

class DisNetwork {
  RawDatagramSocket? _socket;
  DisNetworkConfig? _config;
  final _controller = StreamController<dynamic>.broadcast();
  bool _running = false;

  int _packetsSent = 0;
  int _packetsReceived = 0;
  DateTime? _startTime;

  bool get isRunning => _running;
  int get packetsSent => _packetsSent;
  int get packetsReceived => _packetsReceived;
  Stream<dynamic> get receivedPdus => _controller.stream;

  Future<void> start(DisNetworkConfig config) async {
    await stop();
    _config = config;

    final bindAddress = InternetAddress(
      config.useMulticast ? '0.0.0.0' : config.localAddress,
    );

    _socket = await RawDatagramSocket.bind(
      bindAddress,
      config.port,
      reuseAddress: true,
      reusePort: Platform.isLinux,
    );

    if (config.useMulticast) {
      final multicastAddr = InternetAddress(config.multicastGroup);
      final iface = config.networkInterface != null
          ? (await NetworkInterface.list()).firstWhere(
              (i) => i.name == config.networkInterface,
              orElse: () => (throw Exception('Interface not found')),
            )
          : null;
      if (iface != null) {
        _socket!.joinMulticast(multicastAddr, iface);
      } else {
        _socket!.joinMulticast(multicastAddr);
      }
    }

    _running = true;
    _startTime = DateTime.now();

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _handleReceived(datagram.data);
        }
      }
    });
  }

  Future<void> stop() async {
    _running = false;
    if (_config?.useMulticast == true && _socket != null) {
      try {
        _socket!.leaveMulticast(InternetAddress(_config!.multicastGroup));
      } catch (_) {}
    }
    _socket?.close();
    _socket = null;
  }

  void _send(Uint8List bytes) {
    if (_socket == null || _config == null || !_running) return;
    try {
      final dest = _config!.useMulticast
          ? InternetAddress(_config!.multicastGroup)
          : InternetAddress(_config!.unicastAddress);
      _socket!.send(bytes, dest, _config!.port);
      _packetsSent++;
    } catch (e) {
      print('DIS send error: $e');
    }
  }

  void sendTransmitter(TransmitterPdu pdu) => _send(pdu.encode());
  void sendSignal(SignalPdu pdu) => _send(pdu.encode());
  void sendReceiver(ReceiverPdu pdu) => _send(pdu.encode());
  void sendIntercomSignal(IntercomSignalPdu pdu) => _send(pdu.encode());
  void sendIntercomControl(IntercomControlPdu pdu) => _send(pdu.encode());

  void _handleReceived(Uint8List data) {
    if (data.length < DisConstants.pduHeaderSize) return;
    _packetsReceived++;

    try {
      final header = PduHeader.decode(data);
      dynamic pdu;

      switch (header.pduType) {
        case DisConstants.pduTypeTransmitter:
          pdu = TransmitterPdu.decode(data);
          break;
        case DisConstants.pduTypeSignal:
          pdu = SignalPdu.decode(data);
          break;
        case DisConstants.pduTypeReceiver:
          pdu = ReceiverPdu.decode(data);
          break;
        case DisConstants.pduTypeIntercomSignal:
          pdu = IntercomSignalPdu.decode(data);
          break;
        case DisConstants.pduTypeIntercomControl:
          pdu = IntercomControlPdu.decode(data);
          break;
        default:
          return;
      }

      if (pdu != null) {
        _controller.add(pdu);
      }
    } catch (e) {
      print('DIS receive error: $e');
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
