import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/benin_regions.dart';
import '../home/home_screen.dart';

/// Complétion du profil après la première connexion.
/// Infos essentielles : nom complet, pseudo, date de naissance, genre,
/// département de résidence — la base d'un ciblage boost précis.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  String? _region;
  bool _saving = false;

  int? get _age {
    if (_birthDate == null) return null;
    final now = DateTime.now();
    var a = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) a--;
    return a;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: 'Ta date de naissance',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.normalSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.error));

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final username = _userCtrl.text.trim();
    if (name.length < 2) { _snack('Entre ton nom complet'); return; }
    if (username.length < 3) { _snack('Choisis un nom de compte (3 caractères min)'); return; }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(username)) {
      _snack('Nom de compte : lettres, chiffres et _ uniquement'); return;
    }
    if (_birthDate == null) { _snack('Indique ta date de naissance'); return; }
    if ((_age ?? 0) < 13) { _snack('Tu dois avoir au moins 13 ans'); return; }
    if (_gender == null) { _snack('Sélectionne ton genre'); return; }
    if (_region == null) { _snack('Sélectionne ton département'); return; }

    setState(() => _saving = true);
    final d = _birthDate!;
    final birthDate =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await ApiService.updateProfile(
      fullName: name,
      username: username,
      birthDate: birthDate,
      gender: _gender,
      region: _region,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } else {
      _snack(res['message']?.toString() ?? 'Erreur, réessaie');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: AppColors.normalSurface,
        border: OutlineInputBorder(
            borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.all(16),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            const Text('Complète ton profil 🇧🇯',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Ces informations personnalisent ton expérience et permettent aux créateurs de toucher le bon public.',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),

            const Text('Nom complet', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Ex. : Jean Chanceux GBETOHO', Icons.person_outline),
            ),
            const SizedBox(height: 18),

            const Text('Nom du compte (pseudo)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _userCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Ex. : jean_bj', Icons.alternate_email),
            ),
            const SizedBox(height: 18),

            const Text('Date de naissance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBirthDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.normalSurface, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.cake_outlined, color: Colors.white38, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate == null
                        ? 'Choisir ma date de naissance'
                        : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}  ·  $_age ans',
                    style: TextStyle(color: _birthDate == null ? Colors.white38 : Colors.white),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 18),

            const Text('Genre', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              _choice('Homme', _gender == 'homme', () => setState(() => _gender = 'homme')),
              const SizedBox(width: 10),
              _choice('Femme', _gender == 'femme', () => setState(() => _gender = 'femme')),
            ]),
            const SizedBox(height: 18),

            const Text('Département de résidence', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: AppColors.normalSurface, borderRadius: BorderRadius.circular(14)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _region,
                  isExpanded: true,
                  dropdownColor: AppColors.normalSurface,
                  hint: const Text('Choisir mon département',
                      style: TextStyle(color: Colors.white38)),
                  icon: const Icon(Icons.expand_more, color: Colors.white38),
                  items: BeninRegions.all
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setState(() => _region = v),
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Commencer 🚀',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Tes informations restent privées.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.normalSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? AppColors.primary : Colors.white70,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
