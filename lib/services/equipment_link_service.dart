class EquipmentLinkService {
  EquipmentLinkService._();

  static const String webOrigin = String.fromEnvironment(
    'APP_WEB_ORIGIN',
    defaultValue: 'https://hatyaiwit-borrow.vercel.app',
  );

  static Uri equipmentUri(String equipmentId) {
    final origin = Uri.parse(webOrigin);
    return origin.replace(
      pathSegments: <String>[
        ...origin.pathSegments.where((segment) => segment.isNotEmpty),
        'equipment',
        equipmentId,
      ],
      query: null,
      fragment: null,
    );
  }

  static String? equipmentIdFromRoute(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) return null;
    final uri = Uri.tryParse(routeName.trim());
    if (uri == null) return null;
    return _equipmentIdFromUri(uri);
  }

  static String? equipmentIdFromQr(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final id = _equipmentIdFromUri(uri);
      if (id != null) return id;

      // A URL that is not one of our equipment links must not accidentally
      // match an equipment code or document id.
      if (uri.hasScheme || uri.hasAuthority) return null;
    }

    // Keep older QR labels working. They contain only an equipment id/code.
    return value;
  }

  static String? _equipmentIdFromUri(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final equipmentIndex = segments.indexOf('equipment');
    if (equipmentIndex == -1 || equipmentIndex + 1 >= segments.length) {
      return null;
    }

    final id = segments[equipmentIndex + 1].trim();
    return id.isEmpty ? null : id;
  }
}
