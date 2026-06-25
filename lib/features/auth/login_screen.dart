import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final phone = '+229${_phoneController.text.replaceAll(' ', '')}';
      final result = await ApiService.sendOtp(phone);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpScreen(
            phone: phone,
            serverOtp: result['otp']?.toString(),
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur envoi OTP'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'BP',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  AppStrings.tagline,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 60),

                // Champ téléphone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    labelText: AppStrings.phoneLabel,
                    hintText: AppStrings.phoneHint,
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+229',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 8) {
                      return AppStrings.errorPhone;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Info SMS
                Row(
                  children: const [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textHint),
                    SizedBox(width: 6),
                    Text(
                      'Un code SMS vous sera envoyé',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Bouton
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(AppStrings.sendOtp),
                ),

                const SizedBox(height: 40),

                // Drapeaux pays
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('🇧🇯', style: TextStyle(fontSize: 28)),
                    SizedBox(width: 8),
                    Text(
                      'Fait au Bénin, pour le Bénin',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Conditions
                Text(
                  'En continuant, vous acceptez nos Conditions d\'utilisation\net notre Politique de confidentialité',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
