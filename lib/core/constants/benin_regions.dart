/// Les 12 départements du Bénin, pour le ciblage du boost et la localisation.
class BeninRegions {
  static const List<String> all = [
    'Alibori',
    'Atacora',
    'Atlantique',
    'Borgou',
    'Collines',
    'Couffo',
    'Donga',
    'Littoral',
    'Mono',
    'Ouémé',
    'Plateau',
    'Zou',
  ];

  /// Chef-lieu / ville principale de chaque département (info indicative)
  static const Map<String, String> capitals = {
    'Alibori': 'Kandi',
    'Atacora': 'Natitingou',
    'Atlantique': 'Ouidah',
    'Borgou': 'Parakou',
    'Collines': 'Dassa-Zoumè',
    'Couffo': 'Aplahoué',
    'Donga': 'Djougou',
    'Littoral': 'Cotonou',
    'Mono': 'Lokossa',
    'Ouémé': 'Porto-Novo',
    'Plateau': 'Sakété',
    'Zou': 'Abomey',
  };

  static bool isValid(String? region) => region != null && all.contains(region);
}
