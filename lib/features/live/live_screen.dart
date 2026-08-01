import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/momo_pay_sheet.dart';
import '../../services/chat_service.dart';
import 'gift_sheet.dart';

// ─── Liste des lives en cours (données réelles) ───────────────────────────────

class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen> {
  List<Map<String, dynamic>> _lives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final lives = await ApiService.getActiveLives();
      if (mounted) setState(() { _lives = lives; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Lives en cours 🔴',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LiveBroadcastScreen()));
              _load();
            },
            icon: const Icon(Icons.live_tv, color: AppColors.primary),
            label: const Text('Démarrer',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _lives.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Icon(Icons.live_tv_outlined, color: Colors.white24, size: 64),
                      SizedBox(height: 12),
                      Center(child: Text('Aucun live en cours',
                          style: TextStyle(color: Colors.white54))),
                      SizedBox(height: 4),
                      Center(child: Text('Sois le premier à passer en direct !',
                          style: TextStyle(color: Colors.white30, fontSize: 12))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lives.length,
                      itemBuilder: (_, i) {
                        final live = _lives[i];
                        final host = (live['host_name'] ?? 'Créateur').toString();
                        final price = (live['price'] is num) ? (live['price'] as num).toInt() : 0;
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => LiveViewerScreen(
                              liveId: live['id'].toString(),
                              hostName: host,
                              title: (live['title'] ?? 'Live').toString(),
                              price: price,
                            ),
                          )),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.normalSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Stack(children: [
                              const Center(child: Icon(Icons.live_tv, color: Colors.white24, size: 56)),
                              Positioned(top: 12, left: 12, child: _liveBadge()),
                              if (price > 0)
                                Positioned(top: 12, right: 12, child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.lock, color: Colors.black, size: 11),
                                    const SizedBox(width: 3),
                                    Text('$price F', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ]),
                                )),
                              Positioned(
                                bottom: 12, left: 12, right: 12,
                                child: Row(children: [
                                  CircleAvatar(radius: 18, backgroundColor: AppColors.primary,
                                      child: Text(host.isNotEmpty ? host[0].toUpperCase() : '?',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text((live['title'] ?? 'Live').toString(),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('@$host', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ])),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Rejoindre',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  static Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      );
}

// ─── Diffuser un Live (créateur) — Agora broadcaster ──────────────────────────

class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({super.key});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  RtcEngine? _engine;
  bool _isLive = false;
  bool _joined = false;
  bool _starting = false;
  bool _micOn = true;
  bool _camOn = true;
  // Retouche visage (filtre beauté Agora) : 0 = off, 1 = naturel, 2 = glow.
  // Activée en douceur par défaut → le diffuseur se sent mis en valeur.
  int _beautyLevel = 1;
  int _viewers = 0;
  int _duration = 0;
  Timer? _timer;
  String? _liveId;
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  final ChatService _chat = ChatService();
  StreamSubscription? _chatSub;
  final List<String> _comments = [];
  final ScrollController _commentsScroll = ScrollController();
  String? _flyingGift;

  void _startChat() {
    _chat.connect().then((_) {
      if (_liveId != null) _chat.joinLive(_liveId!);
    });
    _chatSub = _chat.incoming.listen((d) {
      if (!mounted || d['liveId'] != _liveId) return;
      final type = d['type'];
      if (type == 'live_comment') {
        final from = (d['from'] is Map ? d['from']['username'] : null)?.toString() ?? '?';
        _pushComment('@$from: ${d['content']}');
      } else if (type == 'gift') {
        final g = d['gift'] is Map ? d['gift'] : {};
        final from = (d['from'] is Map ? d['from']['username'] : null)?.toString() ?? '?';
        _pushComment('🎁 @$from a envoyé ${g['name']} ${g['emoji']}');
        setState(() => _flyingGift = (g['emoji'] ?? '🎁').toString());
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _flyingGift = null);
        });
      }
    });
  }

  void _pushComment(String line) {
    setState(() => _comments.add(line));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_commentsScroll.hasClients) {
        _commentsScroll.animateTo(_commentsScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _startLive() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Donne un titre à ton live'); return;
    }
    if (_starting) return;
    setState(() => _starting = true);

    if (!await _ensurePermissions()) {
      setState(() => _starting = false);
      _snack('Caméra et micro requis pour diffuser'); return;
    }

    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (price > 0 && price < 100) {
      setState(() => _starting = false);
      _snack('Prix minimum : 100 FCFA (ou 0 pour gratuit)'); return;
    }
    final res = await ApiService.startLive(_titleCtrl.text.trim(), price: price < 0 ? 0 : price);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _starting = false);
      _snack(res['message']?.toString() ?? 'Impossible de démarrer le live'); return;
    }
    _liveId = res['liveId']?.toString();
    final channel = res['channel']?.toString() ?? '';
    final token = res['token']?.toString();
    final appId = (res['appId']?.toString().isNotEmpty == true) ? res['appId'].toString() : AppConfig.agoraAppId;

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) { if (mounted) setState(() => _joined = true); },
        onUserJoined: (conn, uid, elapsed) { if (mounted) setState(() => _viewers++); },
        onUserOffline: (conn, uid, reason) { if (mounted) setState(() => _viewers = _viewers > 0 ? _viewers - 1 : 0); },
      ));
      await engine.enableVideo();
      await engine.startPreview();
      await engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      // Filtre beauté (lissage de peau + éclat) — niveau doux par défaut.
      await _applyBeauty(engine);
      await engine.joinChannel(
        token: token ?? '',
        channelId: channel,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
      _engine = engine;
      setState(() { _isLive = true; _starting = false; });
      _startChat(); // commentaires + cadeaux temps réel
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _duration++);
      });
    } catch (e) {
      setState(() => _starting = false);
      _snack('Erreur Agora : $e');
    }
  }

  // Applique le niveau de retouche visage choisi (0 off / 1 naturel / 2 glow).
  // Best-effort : si l'appareil ne supporte pas l'extension beauté, on ignore
  // l'erreur (le live continue sans filtre).
  Future<void> _applyBeauty([RtcEngine? e]) async {
    final engine = e ?? _engine;
    if (engine == null) return;
    // ÉTAPE CLÉ : activer l'extension « clear vision » d'Agora. SANS elle, la
    // beauté et l'amélioration des couleurs ne s'appliquent PAS au flux vu par
    // les spectateurs. Idempotent (peut être rappelé sans souci).
    try {
      await engine.enableExtension(
        provider: 'agora_video_filters_clear_vision',
        extension: 'clear_vision',
        enabled: true,
      );
    } catch (_) { /* extension absente sur l'appareil : pas bloquant */ }
    try {
      if (_beautyLevel == 0) {
        await engine.setBeautyEffectOptions(
            enabled: false, options: const BeautyOptions());
        await engine.setColorEnhanceOptions(
            enabled: false, options: const ColorEnhanceOptions());
        return;
      }
      final soft = _beautyLevel == 1;
      await engine.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: soft ? 0.3 : 0.55, // éclaircit le teint
          smoothnessLevel: soft ? 0.5 : 0.8, // lisse la peau (boutons, défauts)
          rednessLevel: soft ? 0.1 : 0.2, // bonne mine
          sharpnessLevel: 0.3,
        ),
      );
      // Couleurs plus vives et vivantes, avec protection des tons de peau —
      // rendu « pro » visible par tous les spectateurs.
      await engine.setColorEnhanceOptions(
        enabled: true,
        options: const ColorEnhanceOptions(strengthLevel: 0.5, skinProtectLevel: 0.8),
      );
    } catch (_) { /* appareil non supporté : pas bloquant */ }
  }

  Future<void> _stopLive() async {
    _timer?.cancel();
    if (_liveId != null) { await ApiService.stopLive(_liveId!); }
    await _cleanup();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cleanup() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    _chatSub?.cancel();
    if (_liveId != null) { try { _chat.leaveLive(_liveId!); } catch (_) {} }
    _chat.dispose();
    _cleanup();
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _commentsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Aperçu caméra (local) une fois le moteur prêt
        if (_engine != null && _joined)
          AgoraVideoView(controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ))
        else
          Container(color: const Color(0xFF0A0A0A), child: Center(
            child: _starting
                ? const Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text('Connexion au direct…', style: TextStyle(color: Colors.white54)),
                  ])
                : const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.videocam, color: Colors.white12, size: 80),
                    SizedBox(height: 12),
                    Text('Prêt à diffuser', style: TextStyle(color: Colors.white24)),
                  ]),
          )),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              GestureDetector(
                onTap: () => _isLive ? _confirmStop() : Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white70, size: 22),
              ),
              const Spacer(),
              if (_isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8),
                    const SizedBox(width: 4),
                    Text('LIVE ${_fmt(_duration)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text('$_viewers', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),
          const Spacer(),
          if (!_isLive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Titre de ton live…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true, fillColor: Colors.black54,
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Prix d\'entrée en FCFA (0 = gratuit)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
                    filled: true, fillColor: Colors.black54,
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Laisse vide ou 0 pour un live gratuit. Sinon, seuls les spectateurs qui payent pourront entrer.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _starting ? null : _startLive,
                  icon: const Icon(Icons.live_tv, color: Colors.black),
                  label: const Text('Commencer le Live',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            )
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ctrl(_micOn ? Icons.mic : Icons.mic_off, _micOn ? 'Micro' : 'Muet', _micOn ? Colors.white : Colors.red, () async {
                setState(() => _micOn = !_micOn);
                await _engine?.muteLocalAudioStream(!_micOn);
              }),
              const SizedBox(width: 24),
              _ctrl(_camOn ? Icons.videocam : Icons.videocam_off, 'Caméra', _camOn ? Colors.white : Colors.red, () async {
                setState(() => _camOn = !_camOn);
                await _engine?.muteLocalVideoStream(!_camOn);
              }),
              const SizedBox(width: 18),
              _ctrl(
                Icons.auto_fix_high,
                _beautyLevel == 0 ? 'Beauté off' : (_beautyLevel == 1 ? 'Naturel' : 'Glow ✨'),
                _beautyLevel == 0 ? Colors.white54 : AppColors.primary,
                () async {
                  setState(() => _beautyLevel = (_beautyLevel + 1) % 3);
                  await _applyBeauty();
                },
              ),
              const SizedBox(width: 18),
              _ctrl(Icons.flip_camera_android, 'Retourner', Colors.white, () async {
                await _engine?.switchCamera();
              }),
              const SizedBox(width: 18),
              _ctrl(Icons.stop_circle_outlined, 'Terminer', Colors.red, _confirmStop),
            ]),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ])),

        // Commentaires + cadeaux des spectateurs (temps réel)
        if (_isLive && _comments.isNotEmpty)
          Positioned(
            left: 12, right: 70, bottom: 120,
            child: IgnorePointer(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  controller: _commentsScroll,
                  itemCount: _comments.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Text(_comments[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_flyingGift != null)
          IgnorePointer(child: Center(child: Text(_flyingGift!, style: const TextStyle(fontSize: 120)))),
      ]),
    );
  }

  void _confirmStop() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.normalSurface,
      title: const Text('Terminer le live ?', style: TextStyle(color: Colors.white)),
      content: Text('Durée : ${_fmt(_duration)} · $_viewers spectateurs',
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuer', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () { Navigator.pop(context); _stopLive(); }, child: const Text('Terminer', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _ctrl(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(width: 50, height: 50,
            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4))),
            child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]),
      );
}

// ─── Regarder un Live (spectateur) — Agora audience ───────────────────────────

class LiveViewerScreen extends StatefulWidget {
  final String liveId;
  final String hostName;
  final String title;
  final int price;
  const LiveViewerScreen({super.key, required this.liveId, required this.hostName, required this.title, this.price = 0});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  String? _channel;
  bool _ended = false;
  bool _needPay = false;
  int _price = 0;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<String> _comments = [];

  final ChatService _chat = ChatService();
  StreamSubscription? _chatSub;
  bool _joinedRoom = false;
  String? _flyingGift; // emoji du cadeau en cours d'animation

  @override
  void initState() {
    super.initState();
    _price = widget.price;
    _chat.connect().then((_) => _maybeJoinRoom());
    _chatSub = _chat.incoming.listen(_onLiveEvent);
    _join();
  }

  void _maybeJoinRoom() {
    if (!_joinedRoom && _chat.isConnected) {
      _chat.joinLive(widget.liveId);
      _joinedRoom = true;
    }
  }

  void _onLiveEvent(Map<String, dynamic> d) {
    if (!mounted) return;
    final type = d['type'];
    if (type == 'live_comment' && d['liveId'] == widget.liveId) {
      final from = (d['from'] is Map ? d['from']['username'] : null)?.toString() ?? '?';
      _addComment('@$from: ${d['content']}');
    } else if (type == 'gift' && d['liveId'] == widget.liveId) {
      final g = d['gift'] is Map ? d['gift'] : {};
      final from = (d['from'] is Map ? d['from']['username'] : null)?.toString() ?? '?';
      _addComment('🎁 @$from a envoyé ${g['name']} ${g['emoji']}');
      setState(() => _flyingGift = (g['emoji'] ?? '🎁').toString());
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _flyingGift = null);
      });
    } else if (type == 'gift_error') {
      final noCoins = d['code'] == 'no_coins';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(d['message']?.toString() ?? 'Erreur cadeau'),
        backgroundColor: AppColors.error,
        action: noCoins
            ? SnackBarAction(label: 'Recharger', textColor: Colors.white, onPressed: _openGifts)
            : null,
      ));
    }
  }

  void _addComment(String line) {
    setState(() => _comments.add(line));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _openGifts() {
    GiftSheet.show(context, onSend: (giftKey) => _chat.sendGift(widget.liveId, giftKey));
  }

  Future<void> _pay() async {
    final paid = await MomoPaySheet.show(
      context,
      amount: _price,
      type: 'live',
      description: 'Accès au live : ${widget.title}',
      liveId: widget.liveId,
    );
    if (paid == true && mounted) {
      setState(() => _needPay = false);
      _join();
    }
  }

  Future<void> _join() async {
    final res = await ApiService.getLiveToken(widget.liveId);
    if (!mounted) return;
    if (res['success'] != true) {
      // Live payant non débloqué → on affiche l'écran de paiement
      if (res['code'] == 'payment_required') {
        setState(() {
          _needPay = true;
          _price = (res['price'] is num) ? (res['price'] as num).toInt() : _price;
        });
        return;
      }
      setState(() => _ended = true); return;
    }
    _channel = res['channel']?.toString();
    final token = res['token']?.toString();
    final appId = (res['appId']?.toString().isNotEmpty == true) ? res['appId'].toString() : AppConfig.agoraAppId;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (conn, uid, elapsed) { if (mounted) setState(() => _remoteUid = uid); },
        onUserOffline: (conn, uid, reason) { if (mounted) setState(() { if (_remoteUid == uid) _remoteUid = null; }); },
      ));
      await engine.enableVideo();
      await engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.joinChannel(
        token: token ?? '',
        channelId: _channel ?? '',
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _engine = engine;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _ended = true);
    }
  }

  Future<void> _cleanup() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  void _send() {
    final t = _commentCtrl.text.trim();
    if (t.isEmpty) return;
    _maybeJoinRoom();
    _chat.sendLiveComment(widget.liveId, t); // le serveur nous renvoie l'écho
    _commentCtrl.clear();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    try { _chat.leaveLive(widget.liveId); } catch (_) {}
    _chat.dispose();
    _cleanup();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Vidéo du diffuseur
        if (_engine != null && _remoteUid != null && _channel != null)
          AgoraVideoView(controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: _channel),
          ))
        else if (_needPay)
          Container(color: const Color(0xFF10101A), child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 56),
                const SizedBox(height: 16),
                Text(widget.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Live payant de @${widget.hostName}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pay,
                  icon: const Icon(Icons.lock_open_rounded, size: 20, color: Colors.black),
                  label: Text('Rejoindre pour $_price FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Paiement Mobile Money — accès à ce live en direct',
                    style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
          ))
        else
          Container(color: const Color(0xFF10101A), child: Center(
            child: _ended
                ? const Text('Ce live est terminé', style: TextStyle(color: Colors.white54))
                : const Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text('Connexion au direct…', style: TextStyle(color: Colors.white54)),
                  ]),
          )),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary,
                  child: Text(widget.hostName.isNotEmpty ? widget.hostName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${widget.hostName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              _LiveListScreenState._liveBadge(),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white70, size: 22)),
            ]),
          ),
          Expanded(child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(height: 260, child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _comments.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(_comments[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            )),
          )),
          Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _commentCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Commenter…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true, fillColor: Colors.black54,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(20)),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(onTap: _send, child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
                child: const Icon(Icons.send, color: AppColors.primary, size: 20),
              )),
              const SizedBox(width: 8),
              // Bouton cadeaux/stickers
              GestureDetector(onTap: _openGifts, child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                child: const Icon(Icons.card_giftcard, color: Colors.black, size: 20),
              )),
            ]),
          ),
        ])),

        // Animation du cadeau reçu (emoji géant au centre)
        if (_flyingGift != null)
          IgnorePointer(
            child: Center(
              child: AnimatedScale(
                scale: 1.0, duration: const Duration(milliseconds: 300),
                child: Text(_flyingGift!, style: const TextStyle(fontSize: 120)),
              ),
            ),
          ),
      ]),
    );
  }
}
