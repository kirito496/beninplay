import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque des vidéos + file d'attente de téléchargement à priorité.
///
/// Chaque vidéo est téléchargée EN ENTIER une seule fois vers le stockage du
/// téléphone, puis rejouée depuis ce fichier local (lecture en boucle et
/// re-visionnage = 0 data ; hors-ligne pour les vidéos déjà vues).
///
/// POINT CLÉ — un SEUL téléchargement à la fois :
/// on ne télécharge jamais deux vidéos en parallèle. Toute la bande passante
/// va donc sur UNE seule vidéo → elle finit au plus vite. De plus, la vidéo
/// que l'utilisateur REGARDE (priorité haute) passe toujours DEVANT les
/// préchargements des vidéos à venir (priorité basse). Résultat : la vidéo en
/// cours se termine vite, avant que l'utilisateur ait fini de la regarder,
/// puis les suivantes s'enchaînent une par une.
class VideoCache {
  VideoCache._();

  static final CacheManager _manager = CacheManager(
    Config(
      'bpVideoCache',
      stalePeriod: const Duration(days: 30), // on garde les vidéos longtemps
      maxNrOfCacheObjects: 500,              // beaucoup de vidéos préchargées
      fileService: HttpFileService(),
    ),
  );

  // Deux files : haute priorité (vidéo regardée) et basse (préchargement).
  static final Queue<_Job> _high = Queue<_Job>();
  static final Queue<_Job> _low = Queue<_Job>();
  static final Map<String, _Job> _pending = {}; // dé-doublonne par URL
  static bool _busy = false;

  /// Vidéo à lire MAINTENANT : priorité haute, passe devant les préchargements.
  static Future<File> getForPlayback(String url) => _enqueue(url, high: true);

  /// Vidéo à venir : priorité basse (ne démarre que si rien d'urgent).
  static Future<File> prefetch(String url) => _enqueue(url, high: false);

  static Future<File> _enqueue(String url, {required bool high}) {
    // Déjà demandée ? On réutilise le même job. Si elle devient prioritaire,
    // on la remonte dans la file haute.
    final existing = _pending[url];
    if (existing != null) {
      if (high && !existing.high) {
        existing.high = true;
        _low.remove(existing);
        _high.add(existing);
      }
      return existing.completer.future;
    }
    final job = _Job(url, high);
    _pending[url] = job;
    (high ? _high : _low).add(job);
    _pump();
    return job.completer.future;
  }

  // Traite la file, UN SEUL téléchargement à la fois, la haute priorité d'abord.
  static Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_high.isNotEmpty || _low.isNotEmpty) {
        final job = _high.isNotEmpty ? _high.removeFirst() : _low.removeFirst();
        try {
          final file = await _manager.getSingleFile(job.url);
          job.completer.complete(file);
        } catch (e) {
          job.completer.completeError(e);
        } finally {
          _pending.remove(job.url);
        }
      }
    } finally {
      _busy = false;
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

class _Job {
  final String url;
  bool high;
  final Completer<File> completer = Completer<File>();
  _Job(this.url, this.high);
}
