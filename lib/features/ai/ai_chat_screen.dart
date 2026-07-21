import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Assistant IA de BeninPlay : discute avec le créateur, analyse ses
/// performances et donne des conseils. (Nécessite une clé API Claude côté
/// serveur ; sinon l'assistant renvoie des conseils génériques.)
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
  }

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _Msg {
  final String role; // 'user' | 'assistant'
  final String content;
  _Msg(this.role, this.content);
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    _Msg('assistant',
        "Salut 👋 Je suis ton assistant BeninPlay. Pose-moi une question sur "
        "tes performances, des idées de vidéos, les hashtags ou la monétisation !"),
  ];
  bool _sending = false;

  final List<String> _suggestions = const [
    'Comment gagner plus de vues ?',
    'Analyse mes performances',
    'Idées de vidéos tendance au Bénin',
    'Quels hashtags utiliser ?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg('user', text));
      _sending = true;
    });
    _scrollToEnd();

    // Historique (10 derniers messages, hors le message d'accueil).
    final history = _messages
        .where((m) => m.content.isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    if (history.isNotEmpty) history.removeLast(); // on n'envoie pas le message courant en double

    final reply = await ApiService.aiChat(text, history: history);
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg('assistant', reply));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤖 ', style: TextStyle(fontSize: 20)),
            Text('Assistant IA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _messages.length) return const _TypingBubble();
                return _Bubble(msg: _messages[i]);
              },
            ),
          ),
          // Suggestions rapides (seulement au début).
          if (_messages.length <= 1)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            label: Text(s, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                            onPressed: _sending ? null : () => _send(s),
                          ),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 12, right: 12, top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1, maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Écris ton message…',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : () => _send(),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: _sending ? Colors.white24 : AppColors.primary,
                      child: Icon(Icons.send, color: _sending ? Colors.white38 : Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.normalSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 14, height: 1.35),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.normalSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 34,
          child: Text('•••', style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 2)),
        ),
      ),
    );
  }
}
