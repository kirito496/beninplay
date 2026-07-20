import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/api_service.dart';
import '../core/app_config.dart';

enum MessageType { text, image, video, audio }

MessageType _typeFrom(String? s) =>
    MessageType.values.firstWhere((e) => e.name == (s ?? 'text'), orElse: () => MessageType.text);

class ChatMessage {
  final String id;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime createdAt;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.createdAt,
    this.type = MessageType.text,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'];
    return ChatMessage(
      id: (j['id'] ?? '').toString(),
      senderId: (j['sender_id'] ?? (sender is Map ? sender['id'] : null) ?? '').toString(),
      senderName: sender is Map ? sender['username']?.toString() : null,
      content: (j['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
      type: _typeFrom(j['message_type']?.toString()),
    );
  }

  bool isMine(String? myId) => myId != null && senderId == myId;
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherAvatar;
  final DateTime updatedAt;
  final String? lastMessage; // aperçu du dernier message
  final bool lastMessageMine; // true si c'est moi qui l'ai envoyé
  final int unread; // messages non lus dans cette conversation

  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherAvatar,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageMine = false,
    this.unread = 0,
  });

  String get initial => otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?';

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final other = j['otherUser'] is Map ? Map<String, dynamic>.from(j['otherUser']) : <String, dynamic>{};
    final lm = j['lastMessage'] is Map ? Map<String, dynamic>.from(j['lastMessage']) : null;
    return Conversation(
      id: (j['id'] ?? '').toString(),
      otherUserId: (other['id'] ?? '').toString(),
      otherUserName: (other['username'] ?? 'Utilisateur').toString(),
      otherAvatar: other['avatar_url']?.toString(),
      updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      lastMessage: lm?['content']?.toString(),
      lastMessageMine: lm?['mine'] == true,
      unread: (j['unread'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Connexion WebSocket temps réel (dart:io, sans package externe).
/// Se connecte à `wss://<api>/ws?token=<jwt>` et diffuse les messages entrants.
class ChatService {
  WebSocket? _socket;
  bool _connected = false;
  String? _myUserId;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  /// Événements entrants : { conversationId, message: ChatMessage, mine: bool }
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;
  bool get isConnected => _connected;
  String? get myUserId => _myUserId;

  Future<bool> connect() async {
    if (_connected) return true;
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final wsBase = AppConfig.api.replaceFirst('http', 'ws'); // https→wss, http→ws
      _socket = await WebSocket.connect('$wsBase/ws?token=$token')
          .timeout(const Duration(seconds: 8));
      _connected = true;
      _socket!.listen(
        (data) {
          if (data is! String) return;
          try {
            final d = jsonDecode(data) as Map<String, dynamic>;
            final type = d['type'];
            if (type == 'connected') {
              _myUserId = d['userId']?.toString();
            } else if (type == 'new_message' || type == 'message_sent') {
              final m = d['message'];
              if (m is Map) {
                final msg = ChatMessage.fromJson(Map<String, dynamic>.from(m));
                _incoming.add({
                  'conversationId': d['conversationId']?.toString(),
                  'message': msg,
                  'mine': type == 'message_sent',
                });
              }
            } else if (type == 'live_comment' || type == 'gift' ||
                type == 'gift_ok' || type == 'gift_error') {
              // Événements de live (commentaires + cadeaux) transmis tels quels
              _incoming.add(Map<String, dynamic>.from(d));
            }
          } catch (_) {}
        },
        onDone: () => _connected = false,
        onError: (_) => _connected = false,
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  /// Envoie un message via le WebSocket. Retourne false si non connecté.
  bool sendViaSocket(String conversationId, String content) {
    if (!_connected || _socket == null) return false;
    _socket!.add(jsonEncode({
      'type': 'send_message',
      'conversationId': conversationId,
      'content': content,
      'message_type': 'text',
    }));
    return true;
  }

  // ── Live : salle de commentaires + cadeaux ────────────────────────────────
  void _sendRaw(Map<String, dynamic> d) {
    if (_connected && _socket != null) _socket!.add(jsonEncode(d));
  }

  void joinLive(String liveId) => _sendRaw({'type': 'join_live', 'liveId': liveId});
  void leaveLive(String liveId) => _sendRaw({'type': 'leave_live', 'liveId': liveId});
  void sendLiveComment(String liveId, String content) =>
      _sendRaw({'type': 'live_comment', 'liveId': liveId, 'content': content});
  void sendGift(String liveId, String giftKey) =>
      _sendRaw({'type': 'live_gift', 'liveId': liveId, 'giftKey': giftKey});

  void dispose() {
    try { _socket?.close(); } catch (_) {}
    _connected = false;
    _incoming.close();
  }
}
