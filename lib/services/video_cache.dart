import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque des vidéos.
///
/// Chaque vidéo est téléchargée EN ENTIER une seule fois vers le stockage du
/// téléphone, puis rejouée depuis ce fichier local. Conséquences :
///  • la lecture en boucle ne consomme AUCUNE data (tout est déjà sur le disque)
///  • re-scroller vers une vidéo déjà vue = instantané, sans réseau
///  • on garde un grand nombre de vidéos en cache (préchargement massif)
///
/// La vidéo COURANTE se télécharge d'abord entièrement ; ce n'est qu'ensuite
/// que la SUIVANTE commence à se mettre en cache (voir le lecteur de fil).
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

  /// Télécharge la vidéo EN ENTIER vers le disque (ou renvoie instantanément
  /// le fichier déjà en cache). Sert à la fois à la lecture et au
  /// préchargement de la vidéo suivante.
  static Future<File> getFile(String url) => _manager.getSingleFile(url);

  /// Vrai si la vidéo est déjà entièrement présente sur le disque.
  static Future<bool> isCached(String url) async {
    final info = await _manager.getFileFromCache(url);
    return info != null;
  }

  /// Vide le cache vidéo (option "libérer de l'espace" dans les réglages).
  static Future<void> clear() => _manager.emptyCache();
}
