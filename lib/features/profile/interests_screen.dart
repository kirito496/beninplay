import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

/// « Tes centres d'intérêt » — rend VISIBLE ce que l'algo a appris de toi :
/// tes thèmes préférés (tags des vidéos que tu aimes) et tes créateurs
/// favoris. C'est exactement le signal que la reco utilise pour personnaliser
/// ton fil.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});
  static void open(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => const InterestsScreen()));

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  bool _loading = true;
  int _totalLikes = 0;
  List<Map<String, dynamic>> _interests = [];
  List<Map<String, dynamic>> _creators = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ApiService.getInterests();
    if (!mounted) return;
    setState(() {
      _totalLikes = (r['totalLikes'] is num) ? (r['totalLikes'] as num).toInt() : 0;
      _interests = ((r['interests'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _creators = ((r['creators'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  int get _maxInterest =>
      _interests.isEmpty ? 1 : _interests.map((e) => (e['count'] as num).toInt()).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: AppColors.normalBg,
        title: const Text('Tes centres d\'intérêt', style: TextStyle(fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : (_totalLikes == 0 ? _empty() : _content()),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, color: Colors.white24, size: 56),
              SizedBox(height: 16),
              Text(
                'Aime quelques vidéos pour que l\'algo apprenne ce que tu aimes.\nReviens ici ensuite : tu verras tes thèmes et créateurs préférés.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );

  Widget _content() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF11522B), Color(0xFF07200F)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'L\'algo a analysé tes $_totalLikes j\'aime pour personnaliser ton fil.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_interests.isNotEmpty) ...[
          const Text('Tes thèmes préférés', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Ce que l\'algo te propose le plus.', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          ..._interests.map((it) {
            final count = (it['count'] as num).toInt();
            final ratio = count / _maxInterest;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#${it['tag']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('$count', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.05, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        if (_creators.isNotEmpty) ...[
          const Text('Tes créateurs préférés', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._creators.map((c) {
            final avatar = (c['avatar_url'] ?? '').toString();
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text((c['username'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                    : null,
              ),
              title: Text('@${c['username']}', style: const TextStyle(color: Colors.white)),
              trailing: Text('${c['count']} ❤️', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            );
          }),
        ],

        const SizedBox(height: 24),
        const Text(
          'Plus tu aimes et regardes de vidéos, plus l\'algo affine ce que tu vois. '
          'Aucune donnée n\'est partagée : ça sert uniquement à ton fil.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}
