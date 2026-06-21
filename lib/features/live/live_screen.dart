import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/live_service.dart';

// ─── Liste des lives actifs ───────────────────────────────────────────────────

class LiveListScreen extends StatelessWidget {
  const LiveListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lives = LiveService.activeLives;

    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Lives en cours 🔴',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LiveBroadcastScreen()),
            ),
            icon: const Icon(Icons.live_tv, color: AppColors.primary),
            label: const Text(
              'Démarrer',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lives.length,
        itemBuilder: (_, i) {
          final live = lives[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LiveViewerScreen(live: live)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.normalSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                  // Fond simulé
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black,
                            _colorForHost(live.hostInitial).withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.live_tv, color: Colors.white24, size: 64),
                      ),
                    ),
                  ),
                  // Badge LIVE
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Viewers
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${live.viewers}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Info en bas
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _colorForHost(live.hostInitial),
                            child: Text(
                              live.hostInitial,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  live.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  live.hostName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Rejoindre',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _colorForHost(String initial) {
    const colors = [
      AppColors.primary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.teal,
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }
}

// ─── Regarder un live (spectateur) ───────────────────────────────────────────

class LiveViewerScreen extends StatefulWidget {
  final LiveStream live;
  const LiveViewerScreen({super.key, required this.live});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_LiveComment> _comments = [];
  Timer? _viewerTimer;
  Timer? _commentTimer;
  int _viewers = 0;
  bool _isLiked = false;
  int _likeCount = 0;
  final List<_FloatingHeart> _hearts = [];

  @override
  void initState() {
    super.initState();
    _viewers = widget.live.viewers;
    _likeCount = _viewers * 3;

    _simulateComments();

    _viewerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _viewers += Random().nextInt(5) - 2);
      }
    });
  }

  void _simulateComments() {
    final mockComments = [
      ('Akossi', '🔥🔥🔥 Incroyable !'),
      ('Fatou', 'Waaw beau !!!'),
      ('DjKofi', 'Tu gères vraiment 👑'),
      ('Romuald', 'Quand est-ce que tu refais un live ?'),
      ('Grâce', '❤️❤️❤️'),
      ('YovoBénin', 'Je partage ça direct !'),
      ('BeninFan', 'Depuis Parakou ici 👋'),
      ('CotoviMusic', 'Belle ambiance !'),
    ];

    int idx = 0;
    _commentTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && mockComments.isNotEmpty) {
        final c = mockComments[idx % mockComments.length];
        setState(() => _comments.add(
          _LiveComment(name: c.$1, text: c.$2, time: DateTime.now()),
        ));
        idx++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) { return; }
    setState(() => _comments.add(
      _LiveComment(name: 'Moi', text: text, time: DateTime.now(), isMe: true),
    ));
    _commentCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendHeart() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) { _likeCount++; }
      _hearts.add(_FloatingHeart(id: DateTime.now().millisecondsSinceEpoch));
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _hearts.isNotEmpty) { setState(() => _hearts.removeAt(0)); }
    });
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
              'Soutenir ${widget.live.hostName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
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
                  setState(() {
                    _comments.add(_LiveComment(
                      name: 'Moi',
                      text: '💰 a envoyé $amount FCFA',
                      time: DateTime.now(),
                      isMe: true,
                      isTip: true,
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tip de $amount FCFA envoyé ✓'),
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

  @override
  void dispose() {
    _commentTimer?.cancel();
    _viewerTimer?.cancel();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _colorForHost(String initial) {
    const colors = [
      AppColors.primary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.teal,
    ];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fond vidéo (demo)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A2E),
                  _colorForHost(widget.live.hostInitial).withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.live_tv, color: Colors.white12, size: 120),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _colorForHost(widget.live.hostInitial),
                        child: Text(
                          widget.live.hostInitial,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.live.hostName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            widget.live.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_viewers',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white70, size: 22),
                      ),
                    ],
                  ),
                ),

                // Zone de commentaires
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      height: 300,
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: c.isTip
                                        ? AppColors.primary.withValues(alpha: 0.25)
                                        : Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                    border: c.isTip
                                        ? Border.all(
                                            color: AppColors.primary.withValues(alpha: 0.5),
                                          )
                                        : null,
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${c.name} ',
                                          style: TextStyle(
                                            color: c.isMe ? AppColors.primary : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        TextSpan(
                                          text: c.text,
                                          style: TextStyle(
                                            color: c.isTip ? AppColors.primary : Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Barre du bas
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onSubmitted: (_) => _sendComment(),
                          decoration: InputDecoration(
                            hintText: 'Commenter...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            filled: true,
                            fillColor: Colors.black54,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tip
                      GestureDetector(
                        onTap: _sendTip,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.monetization_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Cœur
                      GestureDetector(
                        onTap: _sendHeart,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _isLiked
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cœurs flottants
          ...(_hearts.map((h) => _FloatingHeartWidget(key: ValueKey(h.id)))),
        ],
      ),
    );
  }
}

// ─── Diffuser un Live (créateur) ──────────────────────────────────────────────

class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({super.key});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  bool _isLive = false;
  bool _isMicOn = true;
  bool _isCamOn = true;
  int _viewers = 0;
  int _duration = 0;
  Timer? _timer;
  final _titleCtrl = TextEditingController();

  void _startLive() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donnez un titre à votre live'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLive = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _duration++;
          if (_duration % 10 == 0) { _viewers += Random().nextInt(8) - 2; }
          if (_viewers < 0) { _viewers = 0; }
        });
      }
    });
  }

  void _stopLive() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.normalSurface,
        title: const Text('Terminer le live ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Votre live a duré ${_formatDuration(_duration)}.\n'
          '$_viewers spectateurs vous ont regardé.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Terminer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF0A0A0A),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, color: Colors.white12, size: 80),
                  SizedBox(height: 16),
                  Text(
                    'Aperçu caméra',
                    style: TextStyle(color: Colors.white24, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '(Actif après configuration Agora)',
                    style: TextStyle(color: Colors.white12, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _isLive ? _stopLive() : Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white70, size: 22),
                      ),
                      const Spacer(),
                      if (_isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, color: Colors.white, size: 8),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE ${_formatDuration(_duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.white70,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_viewers',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                if (!_isLive) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Titre de votre live...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.black54,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _startLive,
                          icon: const Icon(Icons.live_tv, color: Colors.black),
                          label: const Text(
                            'Commencer le Live',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LiveControl(
                        icon: _isMicOn ? Icons.mic : Icons.mic_off,
                        label: _isMicOn ? 'Micro ON' : 'Micro OFF',
                        color: _isMicOn ? Colors.white : Colors.red,
                        onTap: () => setState(() => _isMicOn = !_isMicOn),
                      ),
                      const SizedBox(width: 20),
                      _LiveControl(
                        icon: _isCamOn ? Icons.videocam : Icons.videocam_off,
                        label: _isCamOn ? 'Caméra ON' : 'Caméra OFF',
                        color: _isCamOn ? Colors.white : Colors.red,
                        onTap: () => setState(() => _isCamOn = !_isCamOn),
                      ),
                      const SizedBox(width: 20),
                      _LiveControl(
                        icon: Icons.flip_camera_android,
                        label: 'Retourner',
                        color: Colors.white,
                        onTap: () {},
                      ),
                      const SizedBox(width: 20),
                      _LiveControl(
                        icon: Icons.stop_circle_outlined,
                        label: 'Terminer',
                        color: Colors.red,
                        onTap: _stopLive,
                      ),
                    ],
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets utilitaires ──────────────────────────────────────────────────────

class _LiveComment {
  final String name;
  final String text;
  final DateTime time;
  final bool isMe;
  final bool isTip;

  _LiveComment({
    required this.name,
    required this.text,
    required this.time,
    this.isMe = false,
    this.isTip = false,
  });
}

class _FloatingHeart {
  final int id;
  _FloatingHeart({required this.id});
}

class _FloatingHeartWidget extends StatefulWidget {
  const _FloatingHeartWidget({super.key});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _position;
  late final double _xOffset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)),
    );
    _position = Tween(begin: 0.0, end: -150.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _xOffset = (Random().nextDouble() - 0.5) * 40;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 60 + _xOffset,
      bottom: 100,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(_xOffset * _ctrl.value, _position.value),
          child: Opacity(
            opacity: _opacity.value,
            child: const Icon(Icons.favorite, color: Colors.red, size: 32),
          ),
        ),
      ),
    );
  }
}

class _LiveControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LiveControl({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
