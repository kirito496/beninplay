import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// Ouvre le sheet de paiement MoMo depuis n'importe où :
///
/// ```dart
/// final paid = await MomoPaySheet.show(
///   context,
///   amount: 500,
///   type: 'boost',
///   description: 'Boost vidéo 3 jours',
///   videoId: 'abc123',
/// );
/// if (paid == true) { /* succès */ }
/// ```
class MomoPaySheet extends StatefulWidget {
  final int amount;
  final String type;
  final String? videoId;
  final String description;
  final String? targetRegion;
  final List<String>? targetRegions;
  final String? targetGender;
  final int? targetAgeMin;
  final int? targetAgeMax;
  final int? boostDays;
  final List<String>? targetTags;

  const MomoPaySheet({
    super.key,
    required this.amount,
    required this.type,
    this.videoId,
    required this.description,
    this.targetRegion,
    this.targetRegions,
    this.targetGender,
    this.targetAgeMin,
    this.targetAgeMax,
    this.boostDays,
    this.targetTags,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int amount,
    required String type,
    required String description,
    String? videoId,
    String? targetRegion,
    List<String>? targetRegions,
    String? targetGender,
    int? targetAgeMin,
    int? targetAgeMax,
    int? boostDays,
    List<String>? targetTags,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MomoPaySheet(
        amount: amount,
        type: type,
        description: description,
        videoId: videoId,
        targetRegion: targetRegion,
        targetRegions: targetRegions,
        targetGender: targetGender,
        targetAgeMin: targetAgeMin,
        targetAgeMax: targetAgeMax,
        boostDays: boostDays,
        targetTags: targetTags,
      ),
    );
  }

  @override
  State<MomoPaySheet> createState() => _MomoPaySheetState();
}

// ── États du paiement ─────────────────────────────────────────────────────────

enum _PayStep { select, waiting, success, failed }

class _MomoPaySheetState extends State<MomoPaySheet>
    with SingleTickerProviderStateMixin {
  String _operator = 'mtn';
  final _phoneCtrl = TextEditingController();
  _PayStep _step = _PayStep.select;
  bool _isLoading = false;

  String? _paymentId;
  String? _errorMsg;
  String? _merchantNumber; // numéro marchand renvoyé par le serveur
  int? _payAmount;         // montant exact à envoyer (unique)
  Timer? _pollTimer;
  int _pollCount = 0;
  int _secondsLeft = 180; // 3 minutes
  Timer? _countdownTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _mtnColor  = Color(0xFFFFCC00);
  static const _moovColor = Color(0xFF0066CC);

  Color get _opColor => _operator == 'mtn' ? _mtnColor : _moovColor;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    try {
      final profile = await ApiService.getMyProfile();
      final phone = profile['user']?['phone']?.toString() ?? profile['phone']?.toString() ?? '';
      if (mounted && phone.isNotEmpty) {
        _phoneCtrl.text = phone.replaceAll('+229', '').trim();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Initiation du paiement ─────────────────────────────────────────────────

  Future<void> _initiate() async {
    final rawPhone = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (rawPhone.length < 8) {
      _showError('Entrez votre numéro ${_operator == 'mtn' ? 'MTN' : 'Moov'} complet');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      final result = await ApiService.initiatePayment(
        amount: widget.amount,
        type: widget.type,
        operator: _operator,
        videoId: widget.videoId,
        targetRegion: widget.targetRegion,
        targetRegions: widget.targetRegions,
        targetGender: widget.targetGender,
        targetAgeMin: widget.targetAgeMin,
        targetAgeMax: widget.targetAgeMax,
        boostDays: widget.boostDays,
        targetTags: widget.targetTags,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final p = result['payment'] ?? result;
        setState(() {
          _paymentId = (p['id'] ?? p['paymentId'])?.toString();
          _merchantNumber = (p['paymentNumber'] ?? p['payment_number'])?.toString();
          _payAmount = (p['amount'] as num?)?.toInt() ?? widget.amount;
          _step = _PayStep.waiting;
          _isLoading = false;
          _secondsLeft = 180;
        });
        _startCountdown();
        _startPolling();
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = result['message']?.toString() ?? 'Erreur de paiement';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMsg = e.toString(); });
    }
  }

  // ── Polling statut ─────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_paymentId == null || _pollCount >= 60) {
        _pollTimer?.cancel();
        if (mounted && _step == _PayStep.waiting) {
          setState(() { _step = _PayStep.failed; _errorMsg = 'Délai dépassé. Réessayez.'; });
        }
        return;
      }
      _pollCount++;
      try {
        final result = await ApiService.checkPaymentStatus(_paymentId!);
        if (!mounted) return;
        final status = result['payment']?['status']?.toString() ?? result['status']?.toString() ?? '';
        if (status == 'confirmed' || status == 'success' || status == 'SUCCESSFUL') {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _step = _PayStep.success);
        } else if (status == 'failed' || status == 'FAILED' || status == 'cancelled') {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() {
            _step = _PayStep.failed;
            _errorMsg = 'Paiement refusé ou annulé.';
          });
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  String get _timeLeft {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _reset() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _step = _PayStep.select;
      _paymentId = null;
      _errorMsg = null;
      _pollCount = 0;
      _isLoading = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          if (_step == _PayStep.select) _buildSelect(),
          if (_step == _PayStep.waiting) _buildWaiting(),
          if (_step == _PayStep.success) _buildSuccess(),
          if (_step == _PayStep.failed) _buildFailed(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Étape 1 : Sélection opérateur + numéro ────────────────────────────────

  Widget _buildSelect() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Montant
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_opColor.withValues(alpha: 0.25), _opColor.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _opColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.amount} FCFA',
                  style: TextStyle(color: _opColor, fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(widget.description, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Opérateur
          const Text('Opérateur', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _OpButton(
                label: 'MTN MoMo', color: _mtnColor, emoji: '🟡',
                isSelected: _operator == 'mtn',
                onTap: () => setState(() => _operator = 'mtn'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _OpButton(
                label: 'Moov Money', color: _moovColor, emoji: '🔵',
                isSelected: _operator == 'moov',
                onTap: () => setState(() => _operator = 'moov'),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // Numéro de téléphone
          Text(
            'Votre numéro ${_operator == 'mtn' ? 'MTN' : 'Moov'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '97XXXXXXXX',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 18, letterSpacing: 2),
              prefixText: '+229  ',
              prefixStyle: TextStyle(color: _opColor, fontWeight: FontWeight.bold, fontSize: 16),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: _opColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _opColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _opColor, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Bouton payer
          ElevatedButton(
            onPressed: _isLoading ? null : _initiate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _opColor,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Je vais payer ${_operator == 'mtn' ? 'MTN' : 'Moov'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Tu vas envoyer le montant exact à notre numéro depuis ton MoMo.\nDès qu\'on reçoit le paiement, ton boost s\'active automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Étape 2 : Attente confirmation ────────────────────────────────────────

  Widget _buildWaiting() {
    final number = _merchantNumber ?? '...';
    final amount = _payAmount ?? widget.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Finalise ton paiement',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Depuis ton ${_operator == 'mtn' ? 'MTN MoMo' : 'Moov Money'}, envoie le montant EXACT à notre numéro :',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),

          // Numéro marchand (copiable)
          _copyRow('Numéro', number, () {
            Clipboard.setData(ClipboardData(text: number));
            _toast('Numéro copié');
          }),
          const SizedBox(height: 10),
          // Montant exact (copiable)
          _copyRow('Montant exact', '$amount FCFA', () {
            Clipboard.setData(ClipboardData(text: '$amount'));
            _toast('Montant copié');
          }, highlight: true),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Envoie le montant EXACT (au franc près), sinon on ne pourra pas reconnaître ton paiement.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 18),

          // Bouton qui ouvre le menu MoMo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openUssd,
              icon: const Icon(Icons.dialpad, size: 20),
              label: Text('Ouvrir ${_operator == 'mtn' ? 'MTN MoMo (*880#)' : 'Moov Money (*855#)'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _operator == 'mtn' ? const Color(0xFFFFCC00) : const Color(0xFF0066CC),
                foregroundColor: _operator == 'mtn' ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _operator == 'mtn'
                ? 'Menu MTN : 1 (Transfert) → numéro → montant → motif → PIN'
                : 'Menu Moov : option 1 → numéro → montant → PIN',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 18),

          // Attente confirmation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('En attente du paiement... $_timeLeft',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Le boost s\'active dès qu\'on reçoit ton argent.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reset,
            child: const Text('Annuler', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value, VoidCallback onCopy, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AppColors.primary.withValues(alpha: 0.6) : Colors.white24),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
            color: highlight ? AppColors.primary : Colors.white,
            fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
          label: const Text('Copier', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
      ]),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary, duration: const Duration(seconds: 1)),
    );
  }

  // Ouvre le clavier avec le code USSD du menu MoMo (l'utilisateur finit dans le menu)
  Future<void> _openUssd() async {
    final code = _operator == 'mtn' ? '*880#' : '*855#';
    final uri = Uri.parse('tel:${code.replaceAll('#', '%23')}');
    try {
      if (!await launchUrl(uri)) _toast('Impossible d\'ouvrir le clavier');
    } catch (_) {
      _toast('Compose $code manuellement');
    }
  }

  // ── Étape 3 : Succès ──────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.black, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Paiement confirmé !', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.description, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '${widget.amount} FCFA débités de votre compte ${_operator == 'mtn' ? 'MTN' : 'Moov'}',
            style: const TextStyle(color: AppColors.primary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Fermer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Étape 4 : Échec ───────────────────────────────────────────────────────

  Widget _buildFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2)),
            child: const Icon(Icons.close_rounded, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Paiement échoué', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _errorMsg ?? 'Le paiement a été refusé ou a expiré.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}

// ── Bouton opérateur ──────────────────────────────────────────────────────────

class _OpButton extends StatelessWidget {
  final String label;
  final Color color;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _OpButton({
    required this.label, required this.color, required this.emoji,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white38,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
