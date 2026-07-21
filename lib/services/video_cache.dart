import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque des vidéos + téléchargements EN FLUX, ANNULABLES et à priorité.
///
/// Chaque vidéo est téléchargée en streaming (octet par octet) puis rangée dans
/// le cache disque, et rejouée depuis ce fichier local. Points clés :
///  • un SEUL téléchargement à la fois → toute la connexion sur une vidéo
///  • la vidéo REGARDÉE (priorité haute) COUPE le préchargement en cours d'une
///    vidéo à venir → toute la connexion bascule aussitôt sur elle
///  • annulation instantanée si tu défiles (le téléchargement en flux est
///    interrompu au milieu, contrairement à un téléchargement « d'un bloc »)
///  • lecture en boucle / re-visionnage = 0 data (tout est sur le disque)
class VideoCache {
  VideoCache._();

  static final CacheManager _manager = CacheManager(
    Config(
      'bpVideoCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );

  static final Map<String, _Download> _pending = {}; // url -> job (en file ou actif)
  static final Queue<_Download> _highQ = Queue<_Download>(); // vidéo regardée
  static final Queue<_Download> _lowQ = Queue<_Download>();   // préchargements
  static _Download? _active;

  // Estimation de la vitesse de connexion (octets/seconde), pour choisir HD/480p.
  static double? _speedBps;

  /// Vrai quand la connexion est assez rapide pour la HD (> ~300 Ko/s).
  /// Par défaut (pas encore de mesure) : false → on démarre en 480p léger.
  static bool get fastConnection => _speedBps != null && _speedBps! > 300 * 1024;

  /// Débit estimé en Ko/s (null si pas encore mesuré).
  static double? get speedKbps => _speedBps == null ? null : _speedBps! / 1024;

  /// Vidéo à lire MAINTENANT : priorité haute. Si un préchargement est en cours,
  /// il est COUPÉ pour libérer toute la connexion.
  static Future<File> getForPlayback(String url) => _request(url, high: true);

  /// Vidéo à venir : priorité basse (cédée dès qu'une vidéo regardée arrive).
  static Future<File> prefetch(String url) => _request(url, high: false);

  static Future<File> _request(String url, {required bool high}) async {
    // Déjà demandée ? On réutilise le même job (et on le remonte si besoin).
    final existing = _pending[url];
    if (existing != null) {
      if (high && !existing.high) {
        existing.high = true;
        if (_lowQ.remove(existing)) _highQ.add(existing); // s'il attendait encore
      }
      final f = await existing.completer.future;
      if (f == null) throw Exception('téléchargement annulé');
      return f;
    }

    final d = _Download(url, high);
    _pending[url] = d;
    (high ? _highQ : _lowQ).add(d);

    // Priorité haute demandée alors qu'un PRÉCHARGEMENT (basse priorité) est en
    // cours → on le coupe net pour concentrer la connexion sur cette vidéo.
    if (high && _active != null && !_active!.high) {
      _active!.cancel();
    }

    _pump();
    final f = await d.completer.future;
    if (f == null) throw Exception('téléchargement annulé');
    return f;
  }

  static void _pump() {
    if (_active != null) return;
    _Download? next;
    if (_highQ.isNotEmpty) {
      next = _highQ.removeFirst();
    } else if (_lowQ.isNotEmpty) {
      next = _lowQ.removeFirst();
    }
    if (next == null) return;
    _active = next;
    final job = next;
    _run(job).whenComplete(() {
      _pending.remove(job.url);
      _active = null;
      _pump(); // enchaîne la suivante
    });
  }

  static Future<void> _run(_Download d) async {
    void done(File? f) {
      if (!d.completer.isCompleted) d.completer.complete(f);
    }
    try {
      // Déjà en cache ? → instantané.
      final cached = await _manager.getFileFromCache(d.url);
      if (cached != null) return done(cached.file);
      if (d.cancelled) return done(null);

      final client = http.Client();
      d.client = client;
      final resp = await client.send(http.Request('GET', Uri.parse(d.url)));
      if (resp.statusCode != 200) return done(null);

      final builder = BytesBuilder(copy: false);
      final sw = Stopwatch()..start();
      await for (final chunk in resp.stream) {
        if (d.cancelled) return done(null); // coupé entre deux morceaux
        builder.add(chunk);
      }
      sw.stop();
      if (d.cancelled) return done(null);

      final Uint8List bytes = builder.takeBytes();
      if (bytes.isEmpty) return done(null);
      _measure(bytes.length, sw.elapsedMilliseconds);

      // Range le fichier complet dans le cache disque (LRU, 500 vidéos, 30 j).
      final file = await _manager.putFile(d.url, bytes, fileExtension: 'mp4');
      return done(file);
    } catch (_) {
      // client.close() (annulation) ou erreur réseau → traité comme annulé.
      return done(null);
    } finally {
      try { d.client?.close(); } catch (_) {}
      d.client = null;
    }
  }

  // Met à jour l'estimation de vitesse à partir d'un vrai téléchargement.
  static void _measure(int bytes, int elapsedMs) {
    final secs = elapsedMs / 1000.0;
    if (secs > 0.3 && bytes > 150 * 1024) {
      final bps = bytes / secs;
      _speedBps = _speedBps == null ? bps : (_speedBps! * 0.5 + bps * 0.5);
    }
  }

  /// Vrai si la vidéo est déjà entièrement présente sur le disque.
  static Future<bool> isCached(String url) async {
    final info = await _manager.getFileFromCache(url);
    return info != null;
  }

  /// Vide le cache vidéo (option "libérer de l'espace").
  static Future<void> clear() => _manager.emptyCache();
}

class _Download {
  final String url;
  bool high;
  bool cancelled = false;
  http.Client? client;
  final Completer<File?> completer = Completer<File?>();
  _Download(this.url, this.high);

  /// Coupe le téléchargement en cours : fermer le client interrompt le flux
  /// réseau immédiatement (au milieu du fichier).
  void cancel() {
    cancelled = true;
    try { client?.close(); } catch (_) {}
  }
}
