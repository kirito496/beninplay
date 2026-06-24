import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../payment/payment_screen.dart';

class BoostScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  const BoostScreen({super.key, required this.videoId, required this.videoTitle});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  int _budget = 2000;
  String _objective = 'views';
  bool _nationwide = true;
  final List<String> _regions = [];
  final List<String> _hashtags = [];
  List<int> _targetHours = [];
  int _ageMin = 13, _ageMax = 65;
  String _gender = 'all';

  final List<String> _beninCities = [
    'Cotonou','Porto-Novo','Parakou','Abomey-Calavi',
    'Bohicon','Natitingou','Ouidah','Lokossa',
    'Kandi','Abomey','Djougou','Malanville',
  ];

  final List<String> _popularHashtags = [
    '#Musique','#Humour','#Cuisine','#Mode','#Sport',
    '#Business','#Danse','#Beaute','#Religion','#Actu',
  ];

  final List<Map<String,dynamic>> _budgets = [
    {'amount': 2000, 'label': '2 000 F', 'views': '~500 vues', 'days': '3 jours'},
    {'amount': 5000, 'label': '5 000 F', 'views': '~2 000 vues', 'days': '7 jours'},
    {'amount': 10000, 'label': '10 000 F', 'views': '~5 000 vues', 'days': '14 jours'},
    {'amount': 25000, 'label': '25 000 F', 'views': '~15 000 vues', 'days': '30 jours'},
  ];

  void _submit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          amount: _budget,
          type: 'boost',
          videoId: widget.videoId,
          description: 'Boost "${widget.videoTitle}" — $_budget FCFA',
        ),
      ),
    ).then((paid) {
      if (paid == true && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Boost activé ! Votre vidéo sera priorisée. ✓'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.rocket_launch, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Booster ma video', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.videoTitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 24),

            _sectionTitle('Objectif'),
            const SizedBox(height: 10),
            Row(children: [
              _objBtn('views', Icons.visibility, 'Plus de vues'),
              const SizedBox(width: 8),
              _objBtn('followers', Icons.person_add, 'Abonnes'),
              const SizedBox(width: 8),
              _objBtn('profile', Icons.account_circle, 'Mon profil'),
            ]),
            const SizedBox(height: 20),

            _sectionTitle('Budget & Duree'),
            const SizedBox(height: 10),
            ..._budgets.map((b) => _budgetTile(b)),
            const SizedBox(height: 20),

            _sectionTitle('Zone d\'impact'),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _nationwide,
              onChanged: (v) => setState(() { _nationwide = v; if (v) _regions.clear(); }),
              title: const Text('Tout le Benin', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Montrer a tous les utilisateurs', style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_nationwide) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: _beninCities.map((city) {
                  final sel = _regions.contains(city);
                  return GestureDetector(
                    onTap: () => setState(() { sel ? _regions.remove(city) : _regions.add(city); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.primary : Colors.white24),
                      ),
                      child: Text(city, style: TextStyle(color: sel ? AppColors.primary : Colors.white70, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),

            _sectionTitle('Ciblage Hashtags'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: _popularHashtags.map((tag) {
                final sel = _hashtags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() { sel ? _hashtags.remove(tag) : _hashtags.add(tag); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.accent : Colors.white24),
                    ),
                    child: Text(tag, style: TextStyle(color: sel ? AppColors.accent : Colors.white70, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _sectionTitle('Audience'),
            const SizedBox(height: 10),
            Text('Age : $_ageMin - $_ageMax ans', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            RangeSlider(
              values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
              min: 13, max: 65, divisions: 52,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() { _ageMin = v.start.round(); _ageMax = v.end.round(); }),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _genderBtn('all', 'Tous'),
              const SizedBox(width: 8),
              _genderBtn('male', 'Hommes'),
              const SizedBox(width: 8),
              _genderBtn('female', 'Femmes'),
            ]),
            const SizedBox(height: 20),

            _sectionTitle('Horaire de diffusion'),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6,
              children: List.generate(24, (h) {
                final sel = _targetHours.contains(h);
                final label = '${h.toString().padLeft(2,'0')}h';
                return GestureDetector(
                  onTap: () => setState(() { sel ? _targetHours.remove(h) : _targetHours.add(h); }),
                  child: Container(
                    width: 48, height: 32,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? AppColors.primary : Colors.white24),
                    ),
                    child: Center(child: Text(label, style: TextStyle(color: sel ? AppColors.primary : Colors.white54, fontSize: 11))),
                  ),
                );
              }),
            ),
            if (_targetHours.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Aucun horaire = diffusion toute la journee', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Budget total', style: TextStyle(color: Colors.white70)),
                  Text('$_budget FCFA', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Zone', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(_nationwide ? 'Tout le Benin' : '${_regions.length} villes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Hashtags', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(_hashtags.isEmpty ? 'Tous' : '${_hashtags.length} selectes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.rocket_launch),
              label: Text('Lancer le boost — $_budget FCFA'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15));

  Widget _objBtn(String val, IconData icon, String label) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _objective = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _objective == val ? AppColors.primary.withValues(alpha: 0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _objective == val ? AppColors.primary : Colors.white24),
        ),
        child: Column(children: [
          Icon(icon, color: _objective == val ? AppColors.primary : Colors.white54, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _objective == val ? AppColors.primary : Colors.white54, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  Widget _budgetTile(Map<String,dynamic> b) => GestureDetector(
    onTap: () => setState(() => _budget = b['amount']),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _budget == b['amount'] ? AppColors.primary.withValues(alpha: 0.15) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _budget == b['amount'] ? AppColors.primary : Colors.white24, width: _budget == b['amount'] ? 2 : 1),
      ),
      child: Row(children: [
        if (_budget == b['amount']) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        if (_budget != b['amount']) const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['views'] as String, style: TextStyle(color: _budget == b['amount'] ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)),
          Text(b['days'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Text(b['label'] as String, style: TextStyle(color: _budget == b['amount'] ? AppColors.primary : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    ),
  );

  Widget _genderBtn(String val, String label) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _gender = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _gender == val ? AppColors.primary.withValues(alpha: 0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gender == val ? AppColors.primary : Colors.white24),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: _gender == val ? AppColors.primary : Colors.white54, fontSize: 13)),
      ),
    ),
  );
}