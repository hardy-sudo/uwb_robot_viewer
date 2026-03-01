class AppContext {
  final String region;
  final String site;
  final String floor;

  const AppContext({
    required this.region,
    required this.site,
    required this.floor,
  });

  String get breadcrumb => '$region > $site > $floor';
}
