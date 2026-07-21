import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';

// ─── Écran liste des conversations ───────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _chat = ChatService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _chat.connect();
    // Un nouveau message met la liste à jour (remonte la conversation)
    _sub = _chat.incoming.listen((_) => _load());
  }

  Future<void> _load() async {
    final raw = await ApiService.getConversations();
    if (!mounted) return;
    setState(() {
      _conversations = raw.map((c) => Conversation.fromJson(c)).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _chat.dispose();
    super.dispose();
  }

  Color _color(String initial) {
    const palette = [Colors.teal, Colors.orange, Colors.purple, Colors.blue, Colors.pink, Colors.green];
    return palette[initial.codeUnitAt(0) % palette.length];
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _conversations.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 140),
                      Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 64),
                      SizedBox(height: 12),
                      Center(child: Text('Aucun message', style: TextStyle(color: Colors.white38, fontSize: 16))),
                      SizedBox(height: 4),
                      Center(child: Text('Écris à un créateur depuis son profil',
                          style: TextStyle(color: Colors.white24, fontSize: 13))),
                    ])
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (_, i) {
                        final c = _conversations[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: _color(c.initial),
                            backgroundImage: (c.otherAvatar != null && c.otherAvatar!.isNotEmpty)
                                ? NetworkImage(c.otherAvatar!) : null,
                            child: (c.otherAvatar == null || c.otherAvatar!.isEmpty)
                                ? Text(c.initial, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))
                                : null,
                          ),
                          title: Text('@${c.otherUserName}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: c.unread > 0 ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 15)),
                          subtitle: Text(
                              c.lastMessage == null
                                  ? 'Appuie pour ouvrir la discussion'
                                  : '${c.lastMessageMine ? 'Toi : ' : ''}${c.lastMessage}',
                              style: TextStyle(
                                  color: c.unread > 0 ? Colors.white : Colors.white38,
                                  fontWeight: c.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formatTime(c.updatedAt),
                                  style: TextStyle(
                                      color: c.unread > 0 ? AppColors.primary : Colors.white38,
                                      fontSize: 11)),
                              if (c.unread > 0) ...[
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c.unread > 99 ? '99+' : '${c.unread}',
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: c.id,
                              otherUserId: c.otherUserId,
                              otherUserName: c.otherUserName,
                              chat: _chat,
                            ),
                          )).then((_) => _load()),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Écran de discussion ─────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final ChatService chat;
  final bool ownsChat; // true → cet écran doit fermer le ChatService en sortant

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.chat,
    this.ownsChat = false,
  });

  /// Ouvre (ou crée) une conversation avec un utilisateur puis affiche la discussion.
  static Future<void> openWith(BuildContext context, String userId, {String? name}) async {
    final res = await ApiService.openConversation(userId);
    if (res['success'] != true || res['conversationId'] == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message']?.toString() ?? 'Impossible d\'ouvrir la discussion'),
          backgroundColor: AppColors.error));
      }
      return;
    }
    final other = res['otherUser'] is Map ? Map<String, dynamic>.from(res['otherUser']) : {};
    final chat = ChatService();
    await chat.connect();
    if (!context.mounted) { chat.dispose(); return; }
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: res['conversationId'].toString(),
        otherUserId: userId,
        otherUserName: (other['username'] ?? name ?? 'Utilisateur').toString(),
        chat: chat,
        ownsChat: true,
      ),
    ));
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = widget.chat.incoming.listen(_onIncoming);
  }

  Future<void> _load() async {
    final raw = await ApiService.getChatMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages = raw.map((m) => ChatMessage.fromJson(m)).toList();
      _loading = false;
    });
    _scrollToBottom();
  }

  void _onIncoming(Map<String, dynamic> evt) {
    if (evt['conversationId'] != widget.conversationId) return;
    final msg = evt['message'];
    if (msg is! ChatMessage) return;
    // Évite les doublons (le message optimiste puis l'écho serveur)
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);

    // Envoi temps réel si possible, sinon repli REST
    final viaWs = widget.chat.sendViaSocket(widget.conversationId, text);
    if (!viaWs) {
      final res = await ApiService.sendChatMessage(widget.conversationId, text);
      if (res['success'] == true && res['message'] is Map && mounted) {
        setState(() => _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(res['message']))));
        _scrollToBottom();
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (widget.ownsChat) widget.chat.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.chat.myUserId;
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalSurface,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: AppColors.primary,
              child: Text(widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          Text('@${widget.otherUserName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? const Center(child: Text('Envoie le premier message 👋',
                      style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final mine = m.isMine(myId) || (myId == null && m.senderId != widget.otherUserId);
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            decoration: BoxDecoration(
                              color: mine ? AppColors.primary : AppColors.normalSurface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                            ),
                            child: Text(m.content,
                                style: TextStyle(color: mine ? Colors.black : Colors.white, fontSize: 14)),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                minLines: 1, maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true, fillColor: AppColors.normalSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(24)),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.black, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
