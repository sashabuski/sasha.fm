
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

class StreamingService {
  static const String _tokenServer =
      'https://sasha-download-api.sashabuskin12.workers.dev/api/download';

  static const String _equaliserTopic =
      'sasha-fm-equaliser';

  static const int _equaliserBandCount = 32;

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  Timer? _statusTimer;
  bool _checkingStatus = false;

  // True whenever the C++ broadcaster is connected to LiveKit.
  final ValueNotifier<bool> isBroadcasterLive =
      ValueNotifier<bool>(false);

  // The latest 32 equaliser values, normalised between 0.0 and 1.0.
  final ValueNotifier<List<double>> equaliserBands =
      ValueNotifier<List<double>>(
    List<double>.filled(_equaliserBandCount, 0.0),
  );

  StreamingService() {
    // Check immediately, then every two seconds.
    _checkBroadcastStatus();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkBroadcastStatus(),
    );
  }

  bool get isConnected =>
      _room?.connectionState == ConnectionState.connected;

  // Independently monitor the broadcaster.
  Future<void> _checkBroadcastStatus() async {
    if (_checkingStatus) return;

    _checkingStatus = true;

    try {
      final response = await http
          .get(Uri.parse('$_tokenServer/status'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final isLive = data['broadcasting'] == true;

        if (isBroadcasterLive.value != isLive) {
          isBroadcasterLive.value = isLive;
        }
      } else {
        isBroadcasterLive.value = false;
      }
    } catch (error) {
      debugPrint('Broadcast status check failed: $error');
      isBroadcasterLive.value = false;
    } finally {
      _checkingStatus = false;
    }
  }

  // Connect as a listener.
  Future<void> connectAsListener() async {
    if (isConnected) return;

    final response = await http.post(
      Uri.parse('$_tokenServer/token'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'role': 'listener',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Token request failed: ${response.body}',
      );
    }

    final credentials = jsonDecode(response.body);

    final serverUrl = credentials['serverUrl'] as String;
    final token = credentials['token'] as String;

    final room = Room();

    // Register the data listener before connecting.
    final listener = room.createListener();

    listener.on<DataReceivedEvent>(_handleDataReceived);

    try {
      await room.connect(serverUrl, token);

      _room = room;
      _roomListener = listener;

      debugPrint('Connected to LiveKit as listener.');
    } catch (_) {
      await listener.dispose();
      await room.dispose();
      rethrow;
    }
  }

  // Receive equaliser data from the C++ broadcaster.
  void _handleDataReceived(DataReceivedEvent event) {
    // Ignore all other LiveKit data messages.
    if (event.topic != _equaliserTopic) return;

    // We expect exactly 32 bytes.
    if (event.data.length != _equaliserBandCount) {
      debugPrint(
        'Invalid equaliser packet: '
        '${event.data.length} bytes received.',
      );
      return;
    }

    // Convert each byte (0-255) into a value (0.0-1.0).
    final bands = event.data.map((value) {
      return (value.clamp(0, 255)) / 255.0;
    }).toList(growable: false);

    equaliserBands.value = bands;
  }

  // Disconnect the listener.
  Future<void> disconnect() async {
    final listener = _roomListener;
    final room = _room;

    _roomListener = null;
    _room = null;

    if (listener != null) {
      await listener.dispose();
    }

    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }

    // Reset the equaliser when disconnected.
    equaliserBands.value =
        List<double>.filled(_equaliserBandCount, 0.0);
  }

  Future<void> dispose() async {
    _statusTimer?.cancel();

    await disconnect();

    isBroadcasterLive.dispose();
    equaliserBands.dispose();
  }
}
