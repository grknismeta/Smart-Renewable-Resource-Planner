// Conditional export:
//   Web   (dart.library.js_interop) → full MapLibre GL JS 4.x via JS interop
//   iOS/Android (dart.library.io)   → native MapLibre SDK via maplibre Flutter package
//   Fallback                        → stub (platform unsupported message)
export 'map_view_maplibre_stub.dart'
  if (dart.library.js_interop) 'map_view_maplibre_web.dart'
  if (dart.library.io) 'map_view_maplibre_native.dart';
