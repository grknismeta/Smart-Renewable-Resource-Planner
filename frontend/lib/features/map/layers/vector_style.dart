import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

class SrrpVectorStyle {
  static vtr.Theme get theme {
    final styleMap = {
      "version": 8,
      "name": "SRRP Energy Style",
      "sources": {
        "srrp_hydro": {
          "type": "vector",
          "url": "http://localhost:8000/api/v1/tiles/hydro/{z}/{x}/{y}.pbf" 
        },
        "srrp_restricted": {
          "type": "vector",
          "url": "http://localhost:8000/api/v1/tiles/restricted/{z}/{x}/{y}.pbf" 
        },
        "srrp_energy": {
          "type": "vector",
          "url": "http://localhost:8000/api/v1/tiles/energy/{z}/{x}/{y}.pbf" 
        }
      },
      "layers": [
        {
          "id": "hydro-water",
          "type": "fill",
          "source": "srrp_hydro",
          "source-layer": "hydro",
          "filter": ["==", "feature_type", "Doğal Göl"],
          "paint": {
            "fill-color": "#42a5f5",
            "fill-opacity": 0.5
          }
        },
        {
          "id": "hydro-dam",
          "type": "fill",
          "source": "srrp_hydro",
          "source-layer": "hydro",
          "filter": ["==", "feature_type", "Baraj"],
          "paint": {
            "fill-color": "#39ff14", // Neon Green
            "fill-opacity": 0.8,
            "fill-outline-color": "#ffffff"
          }
        },
        {
          "id": "restricted-zone",
          "type": "fill",
          "source": "srrp_restricted",
          "source-layer": "restricted",
          "paint": {
            "fill-color": "#ff0000",
            "fill-opacity": 0.4
          }
        },
        {
          "id": "energy-corridor",
          "type": "fill",
          "source": "srrp_energy",
          "source-layer": "energy",
          "paint": {
            "fill-color": "#ffeb3b",
            "fill-opacity": 0.3
          }
        }
      ]
    };
    
    return vtr.ThemeReader(logger: const vtr.Logger.console()).read(styleMap);
  }
}
