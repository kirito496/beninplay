import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import 'video_effects.dart';

/// Résultat de la caméra intégrée : chemin du fichier filmé + filtre choisi.
class CameraCaptureResult {
  final String path;
  final String? filter; // 'aucun' ou null = pas de filtre
  const CameraCaptureResult(this.path, this.filter);
}

/// Écran caméra "façon Snapchat" : aperçu en direct avec filtres, beauté,
/// bascule avant/arrière, flash, minuteur, zoom au pincement, et un bouton
/// d'enregistrement rond avec anneau de progression (max 60 s).
///
/// Le filtre est visuel (métadonnée) : il s'affiche sur l'aperçu et il est
/// transmis à l'éditeur, où il sera ré-appliqué à la lecture. Rien n'est
/// ré-encodé sur le téléphone → léger et rapide même sur petit appareil.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _initializing = true;
  String? _error;

  // ── Réglages ──
  String _filter = 'aucun';
  bool _flash = false; // torche pendant l'enregistrement
  int _timer = 0; // 0 / 3 / 10 secondes de minuterie avant l'enregistrement
  bool _grid = false; // grille de cadrage

  // ── Zoom ──
  double _minZoom = 1, _maxZoom = 1, _zoom = 1, _baseZoom = 1;

  // ── Enregistrement ──
  bool _recording = false;
  double _elapsed = 0; // secondes écoulées
  static const double _maxSeconds = 60;
  Timer? _ticker;
  int _countdown = 0; // compte à rebours affiché (minuterie)

  // Ordre des filtres proposés dans la barre du bas.
  static const List<String> _filterOrder = [
    'aucun', 'beaute', 'clair', 'chaud', 'froid', 'vif',
    'rose', 'vintage', 'cinema', 'dramatique', 'sepia', 'nb',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    try {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted) {
        setState(() { _initializing = false; _error = 'Autorise la caméra et le micro pour filmer.'; });
        return;
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() { _initializing = false; _error = 'Aucune caméra détectée.'; });
        return;
      }
      // Démarre sur la caméra arrière si dispo.
      _camIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_camIndex < 0) _camIndex = 0;
      await _startController();
    } catch (e) {
      setState(() { _initializing = false; _error = 'Caméra indisponible : $e'; });
    }
  }

  Future<void> _startController() async {
    final prev = _controller;
    final ctrl = CameraController(
      _cameras[_camIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      _minZoom = await ctrl.getMinZoomLevel();
      _maxZoom = await ctrl.getMaxZoomLevel();
      _zoom = _minZoom;
      await prev?.dispose();
      if (mounted) setState(() { _initializing = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _initializing = false; _error = 'Impossible d\'ouvrir la caméra.'; });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _recording) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _startController();
  }

  Future<void> _toggleFlash() async {
    setState(() => _flash = !_flash);
    // La torche ne s'allume que pendant l'enregistrement ; ici on mémorise le choix.
    if (_recording) {
      try { await _controller?.setFlashMode(_flash ? FlashMode.torch : FlashMode.off); } catch (_) {}
    }
  }

  void _cycleTimer() => setState(() => _timer = _timer == 0 ? 3 : (_timer == 3 ? 10 : 0));

  Future<void> _onZoom(ScaleUpdateDetails d) async {
    if (_maxZoom <= _minZoom) return;
    final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    if ((z - _zoom).abs() < 0.01) return;
    _zoom = z;
    try { await _controller?.setZoomLevel(z); } catch (_) {}
    setState(() {});
  }

  Future<void> _tapRecord() async {
    if (_recording) { await _stop(); return; }
    if (_timer > 0) {
      // Compte à rebours avant de lancer.
      for (var n = _timer; n > 0; n--) {
        if (!mounted) return;
        setState(() => _countdown = n);
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _countdown = 0);
    }
    await _start();
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) return;
    try {
      await c.startVideoRecording();
      if (_flash) { try { await c.setFlashMode(FlashMode.torch); } catch (_) {} }
      _elapsed = 0;
      setState(() => _recording = true);
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _elapsed += 0.1;
        if (_elapsed >= _maxSeconds) { _stop(); return; }
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de démarrer : $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _stop() async {
    final c = _controller;
    _ticker?.cancel();
    if (c == null || !c.value.isRecordingVideo) return;
    try {
      final file = await c.stopVideoRecording();
      try { await c.setFlashMode(FlashMode.off); } catch (_) {}
      if (!mounted) return;
      setState(() => _recording = false);
      // Trop court : on ignore (évite les clips vides).
      if (_elapsed < 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maintiens un peu plus longtemps 🙂')));
        return;
      }
      Navigator.pop(context, CameraCaptureResult(file.path, _filter == 'aucun' ? null : _filter));
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement : $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? _errorView()
          : (_initializing || _controller == null || !_controller!.value.isInitialized)
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _cameraView(),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Wrap(spacing: 10, children: [
                TextButton(onPressed: () => openAppSettings(), child: const Text('Réglages')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Retour'),
                ),
              ]),
            ],
          ),
        ),
      );

  Widget _cameraView() {
    final c = _controller!;
    return GestureDetector(
      onScaleStart: (_) => _baseZoom = _zoom,
      onScaleUpdate: _onZoom,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Aperçu caméra + filtre couleur en direct.
          Center(
            child: VideoFilters.apply(
              _filter,
              AspectRatio(aspectRatio: c.value.aspectRatio, child: CameraPreview(c)),
            ),
          ),

          if (_grid) const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),

          // Compte à rebours de la minuterie.
          if (_countdown > 0)
            Center(child: Text('$_countdown',
                style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 12)]))),

          // ── Barre du haut : fermer + réglages ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 6, left: 8, right: 8,
            child: Row(
              children: [
                _round(Icons.close, () => Navigator.pop(context)),
                const Spacer(),
                if (!_recording) ...[
                  _round(_flash ? Icons.flash_on : Icons.flash_off, _toggleFlash, active: _flash),
                  const SizedBox(width: 10),
                  _timerButton(),
                  const SizedBox(width: 10),
                  _round(Icons.grid_on, () => setState(() => _grid = !_grid), active: _grid),
                ],
              ],
            ),
          ),

          // Durée en cours d'enregistrement.
          if (_recording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text('● ${_elapsed.toStringAsFixed(0)}s',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),

          // ── Bas : filtres + bouton d'enregistrement + flip ──
          Positioned(
            left: 0, right: 0, bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              children: [
                if (!_recording) _filterStrip(),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(width: 56, child: !_recording
                        ? _round(Icons.auto_awesome, () => setState(() => _filter = _filter == 'beaute' ? 'aucun' : 'beaute'),
                            active: _filter == 'beaute', tooltip: 'Beauté')
                        : const SizedBox()),
                    _recordButton(),
                    SizedBox(width: 56, child: !_recording && _cameras.length > 1
                        ? _round(Icons.cameraswitch, _flip)
                        : const SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordButton() {
    return GestureDetector(
      onTap: _tapRecord,
      child: SizedBox(
        width: 84, height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Anneau de progression pendant l'enregistrement.
            if (_recording)
              SizedBox(
                width: 84, height: 84,
                child: CircularProgressIndicator(
                  value: (_elapsed / _maxSeconds).clamp(0.0, 1.0),
                  strokeWidth: 5, color: AppColors.primary, backgroundColor: Colors.white24),
              ),
            Container(
              width: 74, height: 74,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            ),
            // Pastille : ronde (prêt) ou carrée rouge (en cours).
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _recording ? 30 : 62, height: _recording ? 30 : 62,
              decoration: BoxDecoration(
                color: _recording ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(_recording ? 8 : 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterStrip() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filterOrder[i];
          final on = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.black38,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? Colors.white : Colors.white24),
              ),
              child: Text(VideoFilters.labels[f] ?? f,
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: on ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  Widget _timerButton() {
    return GestureDetector(
      onTap: _cycleTimer,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _timer > 0 ? AppColors.primary : Colors.black38, shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Icon(Icons.timer, color: Colors.white, size: 20),
          if (_timer > 0) Padding(padding: const EdgeInsets.only(left: 4),
              child: Text('${_timer}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {bool active = false, String? tooltip}) {
    final w = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: active ? AppColors.primary : Colors.black38, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip, child: w);
  }
}

/// Grille de cadrage (règle des tiers).
class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white24..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
