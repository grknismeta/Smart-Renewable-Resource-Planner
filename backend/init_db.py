from sqlalchemy.orm import Session
from . import models, database, test_data

def init_database():
    """Veritabanını oluşturur ve test verilerini ekler"""
    # Tabloları oluştur
    models.Base.metadata.create_all(bind=database.engine)
    
    # Test verilerini ekle
    db = database.SessionLocal()
    try:
        result = test_data.create_test_data(db)
        if result:
            print("Test verileri başarıyla eklendi:")
            print(f"- Türbinler: {[t.model_name for t in result['turbines'] if t]}")
            print(f"- Paneller: {[p.model_name for p in result['panels'] if p]}")
            print(f"- Test kullanıcısı: {result['user'].email}")
        else:
            print("Test verileri eklenirken bir hata oluştu.")
    except Exception as e:
        print(f"Hata: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    print("Veritabanı başlatılıyor...")
    init_database()
    print("İşlem tamamlandı.")