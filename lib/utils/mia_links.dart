// lib/utils/mia_links.dart
//
// URLs canónicas de MIA Tracker. Un solo lugar para cambiar dominio o rutas.
//
// El build web se sirve bajo https://www.miatracker.com/app/ (ver
// miatrackerweb/vercel.json + <base href="/app/"> en el index.html generado)
// y usa hash strategy, por eso las rutas van después de '#'.
//
// La MISMA URL sirve para los tres casos:
//   - navegador  -> carga el Flutter web y navega a la ruta del '#'
//   - Android    -> App Link (intent-filter con autoVerify + assetlinks.json)
//   - iOS        -> Universal Link (Associated Domains + apple-app-site-association)
// Si la app no está instalada, el sistema abre la web. No hace falta un
// esquema propio tipo miatracker:// para esto.

class MiaLinks {
  /// Dominio usado por Universal Links (iOS) y App Links (Android).
  static const String host = 'www.miatracker.com';

  /// Base pública de la app.
  static const String webBase = 'https://$host/app/';

  /// Prefijo de path bajo el que vive el build web (para normalizar deep links).
  static const String pathPrefix = '/app';

  static String _webUrl(String route, {Map<String, String>? params}) {
    final clean = route.startsWith('/') ? route : '/$route';
    final query = (params == null || params.isEmpty)
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return '$webBase#$clean$query';
  }

  /// Pantalla de solicitudes de restock, posicionada en una solicitud concreta.
  static String restockRequest(int requestId) =>
      _webUrl('/restock-management', params: {'request': '$requestId'});

  /// Home de la app (destinatarios externos, p. ej. proveedores).
  static String get appHome => webBase;

  /// Dato codificado dentro del QR de la orden.
  ///
  /// ⚠️ NO cambiar el formato: qr_complete_order_screen.dart valida
  /// exactamente este prefijo antes de aceptar el escaneo.
  static String orderQrData(int requestId) =>
      'miatracker://restock/complete/$requestId';

  /// Imagen PNG del QR para incrustar en los correos.
  static String qrImageUrl(String data, {int size = 300}) =>
      'https://api.qrserver.com/v1/create-qr-code/?size=${size}x$size'
      '&data=${Uri.encodeQueryComponent(data)}';

  // ==========================================================================
  // NORMALIZACIÓN DE DEEP LINKS
  // ==========================================================================

  /// Convierte cualquier forma en la que llegue un enlace a una ruta interna
  /// (`/restock-management`) más sus query params.
  ///
  /// Acepta todo esto y devuelve lo mismo:
  ///   https://www.miatracker.com/app/#/restock-management?request=12
  ///   https://www.miatracker.com/app/restock-management?request=12
  ///   /app/#/restock-management?request=12
  ///   /restock-management?request=12
  ///
  /// Devuelve `null` si no reconoce una ruta interna.
  static ({String route, Map<String, String> params})? parseRoute(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    var value = raw.trim();

    // Quitar esquema + host si viene una URL absoluta.
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      // Solo http(s) de NUESTRO dominio. Cualquier otro esquema
      // (io.supabase.miatracker://, miatracker://, lo que sea) no es un enlace
      // de correo y se maneja antes, en main.dart.
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;

      String bare(String h) =>
          h.toLowerCase().startsWith('www.') ? h.toLowerCase().substring(4) : h.toLowerCase();
      if (bare(uri.host) != bare(host)) return null; // no es nuestro dominio

      value = uri.path;
      if (uri.hasQuery) value = '$value?${uri.query}';
      if (uri.fragment.isNotEmpty) value = '$value#${uri.fragment}';
    }

    // Quedarse con lo que va después del '#' cuando existe (hash strategy).
    final hashIndex = value.indexOf('#');
    if (hashIndex != -1) {
      final afterHash = value.substring(hashIndex + 1);
      if (afterHash.startsWith('/')) value = afterHash;
    }

    // Quitar el prefijo /app con el que se sirve el build web.
    if (value == pathPrefix || value == '$pathPrefix/') {
      value = '/';
    } else if (value.startsWith('$pathPrefix/')) {
      value = value.substring(pathPrefix.length);
    }

    if (!value.startsWith('/')) value = '/$value';

    // Separar query params.
    final params = <String, String>{};
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) {
      final queryString = value.substring(queryIndex + 1);
      value = value.substring(0, queryIndex);
      try {
        params.addAll(Uri.splitQueryString(queryString));
      } catch (_) {
        // Escape mal formado ('%zz', '%' al final): splitQueryString lanza.
        // Un enlace roto no puede tumbar el arranque de la app: se ignoran
        // los parámetros y se conserva la ruta.
      }
    }

    // Normalizar barra final sobrante.
    if (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    if (value.isEmpty || value == '/') return null;

    return (route: value, params: params);
  }
}
