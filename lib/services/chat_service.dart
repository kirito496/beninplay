import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageType type;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.type = MessageType.text,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    senderId: json['sender_id'] as String,
    senderName: json['sender_name'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isMe: (json['is_me'] as bool?) ?? false,
    type: MessageType.values.firstWhere(
          (e) => e.name == (json['type'] ?? 'text'),
      orElse: () => MessageType.text,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
  };
}

enum MessageType { text, tip, video, image }

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUserInitial;
  final int unreadCount;
  final ChatMessage? lastMessage;
  final bool isOnline;

  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserInitial,
    this.unreadCount = 0,
    this.lastMessage,
    this.isOnline = false,
  });
}

class ChatService {
  // URL du serveur WebSocket — à remplacer par votre URL quand le serveur est prêt
  static const String wsUrl = 'ws://api.beninplay.app/ws/chat';

  WebSocket? _socket;
  final StreamController<ChatMessage> _messageController =
  StreamController<ChatMessage>.broadcast();
  bool _isConnected = false;
  String? _currentUserId;

  Stream<ChatMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  // ── Connexion WebSocket (dart:io intégré, zéro package) ──────────────────
  Future<bool> connect(String userId, String token) async {
    _currentUserId = userId;
    try {
      _socket = await WebSocket.connect(
        '$wsUrl?token=$token&user_id=$userId',
      ).timeout(const Duration(seconds: 5));

      _socket!.listen(
            (data) {
          if (data is String) {
            final json = jsonDecode(data) as Map<String, dynamic>;
            _messageController.add(ChatMessage.fromJson(json));
          }
        },
        onDone: () => _isConnected = false,
        onError: (_) => _isConnected = false,
        cancelOnError: true,
      );

      _isConnected = true;
      return true;
    } catch (_) {
      // Serveur non disponible → mode démo
      _isConnected = false;
      return false;
    }
  }

  // ── Rejoindre une conversation ────────────────────────────────────────────
  void joinConversation(String conversationId) {
    if (_isConnected && _socket != null) {
      _socket!.add(jsonEncode({
        'action': 'join_conversation',
        'conversation_id': conversationId,
      }));
    }
  }

  // ── Envoyer un message ────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUserId ?? 'me',
      senderName: 'Moi',
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
    );

    // Optimistic update : ajouter immédiatement dans le stream
    _messageController.add(message);

    if (_isConnected && _socket != null) {
      _socket!.add(jsonEncode({
        'action': 'send_message',
        'conversation_id': conversationId,
        ...message.toJson(),
      }));
    } else {
      // Mode démo : simuler une réponse automatique
      _simulateReply(content);
    }
  }

  // ── Mode démo : réponses simulées ────────────────────────────────────────
  void _simulateReply(String sentContent) {
    const replies = [
      'Waaw ! Merci beaucoup 🙏',
      'Ok d\'accord, je vais regarder ça',
      'Super contenu ! Continue comme ça 🔥',
      'Merci pour le tip ! ❤️',
      'Je vais publier une nouvelle vidéo bientôt',
      'Oui oui, on peut arranger ça',
      'Akpé ! 😊',
      '👍👍👍',
    ];

    final delay = Duration(milliseconds: 800 + Random().nextInt(2000));
    Future.delayed(delay, () {
      if (!_messageController.isClosed) {
        _messageController.add(ChatMessage(
          id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'other',
          senderName: '',
          content: replies[Random().nextInt(replies.length)],
          timestamp: DateTime.now(),
          isMe: false,
          isRead: true,
        ));
      }
    });
  }

  // ── Marquer comme lu ──────────────────────────────────────────────────────
  void markAsRead(String conversationId) {
    if (_isConnected && _socket != null) {
      _socket!.add(jsonEncode({
        'action': 'mark_read',
        'conversation_id': conversationId,
      }));
    }
  }

  void disconnect() {
    _socket?.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }

  // ── Données demo ──────────────────────────────────────────────────────────
  static final List<Conversation> mockConversations = [
    Conversation(
      id: 'conv_1',
      otherUserId: 'user_akossi',
      otherUserName: 'Akossi TV',
      otherUserInitial: 'A',
      unreadCount: 3,
      isOnline: true,
      lastMessage: ChatMessage(
        id: 'm1',
        senderId: 'user_akossi',
        senderName: 'Akossi TV',
        content: 'Super vidéo ! Tu collabores quand ? 🔥',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
    ),
    Conversation(
      id: 'conv_2',
      otherUserId: 'user_fatou',
      otherUserName: 'Fatou K.',
      otherUserInitial: 'F',
      unreadCount: 1,
      isOnline: true,
      lastMessage: ChatMessage(
        id: 'm2',
        senderId: 'user_fatou',
        senderName: 'Fatou K.',
        content: 'T\'a envoyé un tip de 500 FCFA',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isMe: false,
        type: MessageType.tip,
      ),
    ),
    Conversation(
      id: 'conv_3',
      otherUserId: 'user_kofi',
      otherUserName: 'DjKofi',
      otherUserInitial: 'D',
      unreadCount: 0,
      isOnline: false,
      lastMessage: ChatMessage(
        id: 'm3',
        senderId: 'me',
        senderName: 'Moi',
        content: 'Ok je vais regarder ça ce soir',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isMe: true,
      ),
    ),
    Conversation(
      id: 'conv_4',
      otherUserId: 'user_romuald',
      otherUserName: 'Romuald B.',
      otherUserInitial: 'R',
      unreadCount: 0,
      isOnline: false,
      lastMessage: ChatMessage(
        id: 'm4',
        senderId: 'user_romuald',
        senderName: 'Romuald B.',
        content: 'Merci pour le contenu exclusif !',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isMe: false,
      ),
    ),
    Conversation(
      id: 'conv_5',
      otherUserId: 'user_grace',
      otherUserName: 'Grâce M.',
      otherUserInitial: 'G',
      unreadCount: 0,
      isOnline: true,
      lastMessage: ChatMessage(
        id: 'm5',
        senderId: 'user_grace',
        senderName: 'Grâce M.',
        content: 'J\'adore ta danse ! Enseigne-moi 😂',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isMe: false,
      ),
    ),
  ];

  static List<ChatMessage> mockHistory(String conversationId) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'h1',
        senderId: conversationId,
        senderName: '',
        content: 'Salut ! J\'ai vu ta dernière vidéo 🔥',
        timestamp: now.subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      ChatMessage(
        id: 'h2',
        senderId: 'me',
        senderName: 'Moi',
        content: 'Merci ! Tu as aimé ?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 59)),
        isMe: true,
      ),
      ChatMessage(
        id: 'h3',
        senderId: conversationId,
        senderName: '',
        content: 'Oui énormément ! La partie danse était excellente',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 50)),
        isMe: false,
      ),
      ChatMessage(
        id: 'h4',
        senderId: 'me',
        senderName: 'Moi',
        content: 'Akpé ! Je vais en faire d\'autres cette semaine',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
        isMe: true,
      ),
      ChatMessage(
        id: 'h5',
        senderId: conversationId,
        senderName: '',
        content: 'Super contenu ! Tu collabores quand ? 🔥',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
    ];
  }
}
