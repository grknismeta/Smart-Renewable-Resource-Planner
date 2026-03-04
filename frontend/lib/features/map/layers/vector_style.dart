import 'package:flutter/material.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

class SrrpVectorStyle {
  static Style get style {
    final styleMap = {
      "version": 8,
      "name": "SRRP Energy Style",
      "sources": {
        "srrp_mvt": {
          "type": "vector",
          "url": "http://localhost:8000/api/v1/tiles/{z}/{x}/{y}.pbf" 
          // Note: URL doesn't load from here in vector_map_tiles normally, 
          // we use NetworkVectorTileProvider. This is just for schema conformity.
        }
      },
      "layers": [
        {
          "id": "hydro-water",
          "type": "fill",
          "source": "srrp_mvt",
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
          "source": "srrp_mvt",
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
          "source": "srrp_mvt",
          "source-layer": "restricted",
          "paint": {
            "fill-color": "#ff0000",
            "fill-opacity": 0.4
          }
        },
        {
          "id": "energy-corridor",
          "type": "fill",
          "source": "srrp_mvt",
          "source-layer": "energy",
          "paint": {
            "fill-color": "#ffeb3b",
            "fill-opacity": 0.3
          }
        }
      ]
    };
    
    return StyleReader(uri: '', logger: const Logger.console()).read(styleMap);
  }
}
