class Routes {
  const Routes._();

  static const login = '/login';
  static const home = '/';
  static const announcementBase = '/pengumuman';
  static const announcement = '$announcementBase/:id';
  static const announcementIdParam = 'id';

  static String announcementPath(String id) => '$announcementBase/$id';
}

String routeFromMessage(Map<String, dynamic> data) {
  final route = (data['route'] ?? Routes.home).toString().trim();
  if (route.isEmpty) return Routes.home;
  return route.startsWith('/') ? route : '/$route';
}
