from sqlalchemy.orm import Session
from . import models, schemas, crud

def create_test_data(db: Session):
    """Test verileri oluşturur"""
    
    # 1. Standart rüzgar türbini
    default_turbine = schemas.TurbineCreate(
        model_name="Standart 2MW Türbin",
        rated_power_kw=2000,
        is_default=True,
        power_curve_data={
            0: 0,    # cut-in speed öncesi
            3: 0,    # cut-in speed
            4: 70,
            5: 150,
            6: 300,
            7: 500,
            8: 800,
            9: 1200,
            10: 1600,
            11: 1900,
            12: 2000, # rated speed
            13: 2000,
            14: 2000,
            15: 2000,
            25: 0     # cut-out speed
        }
    )
    
    # 2. Test türbini (daha küçük)
    test_turbine = schemas.TurbineCreate(
        model_name="Test 500kW Türbin",
        rated_power_kw=500,
        is_default=False,
        power_curve_data={
            0: 0,
            3: 0,
            4: 20,
            5: 50,
            6: 100,
            7: 200,
            8: 300,
            9: 400,
            10: 500,
            11: 500,
            25: 0
        }
    )
    
    # 3. Standart güneş paneli
    default_panel = schemas.SolarPanelCreate(
        model_name="Standart 400W Panel",
        power_rating_w=400,
        dimensions_m={"length": 2.0, "width": 1.0},  # 2m²/panel
        base_efficiency=0.15,  # %15 verim
        temp_coefficient=-0.005,  # -%0.5/°C
        is_default=True
    )
    
    # 4. Yüksek verimli test paneli
    test_panel = schemas.SolarPanelCreate(
        model_name="Premium 600W Panel",
        power_rating_w=600,
        dimensions_m={"length": 2.1, "width": 1.1},  # 2.31m²/panel
        base_efficiency=0.21,  # %21 verim
        temp_coefficient=-0.003,  # -%0.3/°C
        is_default=False
    )
    
    # Verileri veritabanına ekle
    turbines = [
        crud.create_turbine(db, default_turbine),
        crud.create_turbine(db, test_turbine)
    ]
    
    panels = [
        crud.create_solar_panel(db, default_panel),
        crud.create_solar_panel(db, test_panel)
    ]
    
    # Test kullanıcısı oluştur
    test_user = schemas.UserCreate(
        email="test@example.com",
        password="testpassword123"
    )
    user = crud.create_user(db, test_user)
    
    if not user:
        return None
    
    # Test pinleri oluştur
    test_pins = [
        # İzmir'de rüzgar türbini
        schemas.PinCreate(
            latitude=38.4189,
            longitude=27.1287,
            name="İzmir Rüzgar Test",
            type="Rüzgar Türbini",
            turbine_model_id=turbines[0].id.scalar() if turbines[0] else None
        ),
        # Antalya'da güneş paneli
        schemas.PinCreate(
            latitude=36.8969,
            longitude=30.7133,
            name="Antalya Güneş Test",
            type="Güneş Paneli",
            panel_model_id=panels[0].id.scalar() if panels[0] else None,
            panel_tilt=35.0,
            panel_azimuth=180.0,
            panel_area=100.0  # 100m² panel alanı
        )
    ]
    
    for pin in test_pins:
        user_id = db.query(models.User.id).filter_by(id=user.id).scalar()
        crud.create_pin_for_user(db, pin=pin, user_id=user_id)
    
    return {
        "turbines": turbines,
        "panels": panels,
        "user": user
    }