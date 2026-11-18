
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

class StreamingService {
  static const String _tokenServer =
      'http://127.0.0.1:3000';

  Room? _room;

  Timer? _statusTimer;
  bool _checkingStatus = false;

  // True whenever the C++ broadcaster is connected to LiveKit.
  final ValueNotifier<bool> isBroadcasterLive =
      ValueNotifier<bool>(false);

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

    try {
      await room.connect(serverUrl, token);
      _room = room;
    } catch (_) {
      await room.dispose();
      rethrow;
    }
  }

  // Disconnect the listener.
  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }
  }

  Future<void> dispose() async {
    _statusTimer?.cancel();

    await disconnect();

    isBroadcasterLive.dispose();
  }
}
