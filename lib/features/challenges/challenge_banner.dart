import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/challenge_service.dart';
import 'challenge_screen.dart';

/// Bannière du Défi à Cagnotte en cours (affichée dans Découvrir).
/// Se charge toute seule ; invisible s'il n'y a aucun défi actif.
class ChallengeBanner extends StatefulWidget {
  const ChallengeBanner({super.key});

  @override
  State<ChallengeBanner> createState() => _ChallengeBannerState();
}

class _ChallengeBannerState extends State<ChallengeBanner> {
  Challenge? _ch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ChallengeService.getAll();
    if (mounted && all.active.isNotEmpty) {
      setState(() => _ch = all.active.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = _ch;
    if (ch == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => ChallengeScreen.open(context, ch.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFFF5A623).withValues(alpha: 0.30),
              AppColors.primary.withValues(alpha: 0.10),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Défi #${ch.hashtag} — ${ch.prizePool} FCFA à gagner !',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text('⏳ Fin dans ${ch.remainingLabel} · Appuie pour participer',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ]),
        ),
      ),
    );
  }
}
