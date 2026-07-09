import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_service.dart';
import '../../core/app_config.dart';
import '../../core/constants/app_colors.dart';

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
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => LiveViewerScreen(
                              liveId: live['id'].toString(),
                              hostName: host,
                              title: (live['title'] ?? 'Live').toString(),
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
  int _viewers = 0;
  int _duration = 0;
  Timer? _timer;
  String? _liveId;
  final _titleCtrl = TextEditingController();

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

    final res = await ApiService.startLive(_titleCtrl.text.trim());
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
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _duration++);
      });
    } catch (e) {
      setState(() => _starting = false);
      _snack('Erreur Agora : $e');
    }
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
    _cleanup();
    _titleCtrl.dispose();
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
              const SizedBox(width: 24),
              _ctrl(Icons.flip_camera_android, 'Retourner', Colors.white, () async {
                await _engine?.switchCamera();
              }),
              const SizedBox(width: 24),
              _ctrl(Icons.stop_circle_outlined, 'Terminer', Colors.red, _confirmStop),
            ]),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ])),
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
  const LiveViewerScreen({super.key, required this.liveId, required this.hostName, required this.title});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  String? _channel;
  bool _ended = false;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<String> _comments = [];

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    final res = await ApiService.getLiveToken(widget.liveId);
    if (!mounted) return;
    if (res['success'] != true) {
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
    setState(() => _comments.add('Moi: $t'));
    _commentCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
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
            ]),
          ),
        ])),
      ]),
    );
  }
}
