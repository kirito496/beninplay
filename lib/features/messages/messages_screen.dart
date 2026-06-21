import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';

// ─── Écran liste des conversations ───────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _chatService = ChatService();
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    setState(() => _conversations = List.from(ChatService.mockConversations));
    _chatService.connect('user_gbetoho', 'demo_token');
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) { return '${diff.inMinutes}min'; }
    if (diff.inHours < 24) { return '${diff.inHours}h'; }
    if (diff.inDays == 1) { return 'Hier'; }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            onPressed: () => _showNewMessage(),
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Aucun message',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tes conversations apparaîtront ici',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (_, i) {
                final conv = _conversations[i];
                final last = conv.lastMessage;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _colorForInitial(conv.otherUserInitial),
                        child: Text(
                          conv.otherUserInitial,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (conv.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.normalBg, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.otherUserName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (last != null)
                        Text(
                          _formatTime(last.timestamp),
                          style: TextStyle(
                            color: conv.unreadCount > 0 ? AppColors.primary : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      if (last?.isMe == true)
                        const Icon(Icons.done_all, size: 14, color: AppColors.primary),
                      if (last?.isMe == true) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          last?.type == MessageType.tip
                              ? '💰 ${last!.content}'
                              : (last?.content ?? ''),
                          style: TextStyle(
                            color: conv.unreadCount > 0 ? Colors.white70 : Colors.white38,
                            fontSize: 13,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      final idx = _conversations.indexWhere((c) => c.id == conv.id);
                      if (idx != -1) {
                        _conversations[idx] = Conversation(
                          id: conv.id,
                          otherUserId: conv.otherUserId,
                          otherUserName: conv.otherUserName,
                          otherUserInitial: conv.otherUserInitial,
                          unreadCount: 0,
                          lastMessage: conv.lastMessage,
                          isOnline: conv.isOnline,
                        );
                      }
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversation: conv,
                          chatService: _chatService,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showNewMessage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nouveau message',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un créateur...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: sc,
                children: ChatService.mockConversations.map((c) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorForInitial(c.otherUserInitial),
                    child: Text(
                      c.otherUserInitial,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.otherUserName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    c.isOnline ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      color: c.isOnline ? AppColors.success : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversation: c,
                          chatService: _chatService,
                        ),
                      ),
                    );
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForInitial(String initial) {
    const colors = [
      AppColors.primary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }
}

// ─── Écran de chat individuel ─────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final ChatService chatService;

  const ChatScreen({super.key, required this.conversation, required this.chatService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late StreamSubscription _sub;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(ChatService.mockHistory(widget.conversation.id));
    widget.chatService.joinConversation(widget.conversation.id);

    _sub = widget.chatService.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _sub.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) { return; }
    _textController.clear();

    await widget.chatService.sendMessage(
      conversationId: widget.conversation.id,
      content: text,
    );

    if (!widget.chatService.isConnected) {
      setState(() => _isTyping = true);
    }
    _scrollToBottom();
  }

  void _sendTip() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.normalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Envoyer un tip à ${widget.conversation.otherUserName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [100, 250, 500, 1000, 2000, 5000].map((amount) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.chatService.sendMessage(
                    conversationId: widget.conversation.id,
                    content: 'T\'a envoyé un tip de $amount FCFA',
                    type: MessageType.tip,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tip de $amount FCFA envoyé à ${widget.conversation.otherUserName} ✓',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$amount FCFA',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _colorForInitial(String initial) {
    const colors = [
      AppColors.primary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;

    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalSurface,
        leadingWidth: 30,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _colorForInitial(conv.otherUserInitial),
                  child: Text(
                    conv.otherUserInitial,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (conv.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.normalSurface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  conv.isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    color: conv.isOnline ? AppColors.success : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white70),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appel vidéo bientôt disponible'),
                backgroundColor: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return _TypingIndicator(name: conv.otherUserName);
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // Barre d'envoi
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: AppColors.normalSurface,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _sendTip,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monetization_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final isTip = message.type == MessageType.tip;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isTip
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : isMe
                        ? AppColors.primary
                        : AppColors.normalSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isTip
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isTip)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message.content,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.black : Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isMe ? Colors.black45 : Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: Colors.black45,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Indicateur "en train d'écrire" ──────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  final String name;
  const _TypingIndicator({required this.name});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.normalSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: (i * 0.2 + _anim.value).clamp(0.3, 1.0),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
