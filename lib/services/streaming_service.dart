
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

class StreamingService {
  static const String _tokenServer =
      'http://127.0.0.1:3000/token';

  Room? _room;

  bool get isConnected =>
      _room?.connectionState == ConnectionState.connected;

  Future<void> connectAsListener() async {
    if (isConnected) return;

    // Request a listener token from our Node server.
    final response = await http.post(
      Uri.parse(_tokenServer),
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

    // Create and connect to the LiveKit room.
    final room = Room();

    try {
      await room.connect(
        serverUrl,
        token,
      );

      _room = room;
    } catch (_) {
      await room.dispose();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
