import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getNotifications();
      final List<dynamic> list = res['notifications'] ?? [];
      if (mounted) {
        setState(() {
          _items = list.whereType<Map<String, dynamic>>().toList();
          _loading = false;
        });
      }
      // Marque tout comme lu à l'ouverture
      await ApiService.markNotificationsRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'follow': return Icons.person_add_alt_1;
      case 'purchase': return Icons.shopping_bag;
      case 'live_purchase': return Icons.live_tv;
      case 'withdrawal': return Icons.account_balance_wallet;
      case 'kyc': return Icons.badge;
      case 'creator': return Icons.star;
      case 'monetization': return Icons.monetization_on;
      default: return Icons.notifications;
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'à l\'instant';
    if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'il y a ${d.inHours} h';
    if (d.inDays < 7) return 'il y a ${d.inDays} j';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.normalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 140),
                      Icon(Icons.notifications_none, color: Colors.white24, size: 64),
                      SizedBox(height: 12),
                      Center(child: Text('Aucune notification pour le moment',
                          style: TextStyle(color: Colors.white54))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        final read = n['read'] == true;
                        final type = (n['type'] ?? '').toString();
                        return Container(
                          color: read ? Colors.transparent : AppColors.primary.withValues(alpha: 0.06),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                              child: Icon(_iconFor(type), color: AppColors.primary, size: 20),
                            ),
                            title: Text((n['title'] ?? '').toString(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: read ? FontWeight.w500 : FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if ((n['body'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(n['body'].toString(),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                                ),
                              const SizedBox(height: 4),
                              Text(_timeAgo(n['created_at']?.toString()),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
