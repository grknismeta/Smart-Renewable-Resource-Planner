import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

class SrrpVectorStyle {
  static final Map<String, dynamic> _styleMap = {
    "version": 8,
    "name": "SRRP Energy Style",
    "sources": {
      "srrp_all": {
        "type": "vector",
        "url": "http://localhost:8000/api/v1/tiles/{z}/{x}/{y}.pbf"
      }
    },
    "layers": [
      {
        "id": "hydro-water",
        "type": "fill",
        "source": "srrp_all",
        "source-layer": "hydro",
        "filter": ["==", "feature_type", "water"],
        "paint": {
          "fill-color": "#42a5f5",
          "fill-opacity": 0.5
        }
      },
      {
        "id": "hydro-reservoir",
        "type": "fill",
        "source": "srrp_all",
        "source-layer": "hydro",
        "filter": ["==", "feature_type", "reservoir"],
        "paint": {
          "fill-color": "#1e88e5",
          "fill-opacity": 0.6
        }
      },
      {
        "id": "hydro-dam",
        "type": "fill",
        "source": "srrp_all",
        "source-layer": "hydro",
        "filter": ["==", "feature_type", "dam"],
        "paint": {
          "fill-color": "#39ff14",
          "fill-opacity": 0.8,
          "fill-outline-color": "#ffffff"
        }
      },
      {
        "id": "restricted-zone",
        "type": "fill",
        "source": "srrp_all",
        "source-layer": "restricted",
        "paint": {
          "fill-color": "#ff0000",
          "fill-opacity": 0.35
        }
      },
      {
        "id": "energy-corridor",
        "type": "fill",
        "source": "srrp_all",
        "source-layer": "energy",
        "minzoom": 11,
        "paint": {
          "fill-color": "#ffeb3b",
          "fill-opacity": 0.25
        }
      }
    ]
  };

  /// Uygulama boyunca tek seferlik oluşturulur.
  /// getter değil static final — her build()'de yeni nesne oluşturmaz.
  static final vtr.Theme theme = vtr.ThemeReader(
    logger: const vtr.Logger.console(),
  ).read(_styleMap);
}
