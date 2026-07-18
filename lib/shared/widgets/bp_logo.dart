import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Logo BeninPlay dessiné (en attendant le logo officiel) :
/// un bouton "play" blanc dans un carré arrondi en dégradé vert,
/// souligné par les couleurs du drapeau du Bénin.
class BpLogo extends StatelessWidget {
  final double size;
  const BpLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00E676), AppColors.primary, Color(0xFF00897B)],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: size * 0.28,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * 0.62,
          ),
        ),
        SizedBox(height: size * 0.14),
        // Rappel du drapeau béninois : vert / jaune / rouge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _flagDot(AppColors.primary),
            const SizedBox(width: 5),
            _flagDot(AppColors.accent),
            const SizedBox(width: 5),
            _flagDot(const Color(0xFFE53935)),
          ],
        ),
      ],
    );
  }

  Widget _flagDot(Color c) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
