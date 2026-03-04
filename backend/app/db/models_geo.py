from sqlalchemy import Column, Integer, String, Float, Boolean
from geoalchemy2 import Geometry
from .database import SystemBase

class HydroFeature(SystemBase):
    __tablename__ = "hydro_features"
    id = Column(Integer, primary_key=True, index=True)
    geom = Column(Geometry('MULTIPOLYGON', srid=4326), index=True)
    min_zoom = Column(Integer, default=5)
    feature_type = Column(String)  # 'Baraj', 'Nehir', 'Doğal Göl' vs.
    energy_capacity_mw = Column(Float, nullable=True)

class RestrictedZone(SystemBase):
    __tablename__ = "restricted_zones"
    id = Column(Integer, primary_key=True, index=True)
    geom = Column(Geometry('MULTIPOLYGON', srid=4326), index=True)
    min_zoom = Column(Integer, default=5)
    feature_type = Column(String)  # 'Askeri Alan', 'Koruma Alanı' vs.
    description = Column(String, nullable=True)

class EnergyCorridor(SystemBase):
    __tablename__ = "energy_corridors"
    id = Column(Integer, primary_key=True, index=True)
    geom = Column(Geometry('MULTIPOLYGON', srid=4326), index=True)
    min_zoom = Column(Integer, default=5)
    feature_type = Column(String)  # 'Rüzgar Koridoru', 'Güneş Sahası' vs.
    energy_capacity_mw = Column(Float, nullable=True)
