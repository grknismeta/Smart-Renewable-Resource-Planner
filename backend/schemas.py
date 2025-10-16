from pydantic import BaseModel

# Dışarıdan bir kaynak (resource) oluşturmak için gelecek verinin
# hangi alanları içermesi gerektiğini tanımlayan Pydantic modeli.
# Kullanıcıdan id beklemiyoruz, çünkü onu veritabanı otomatik atayacak.
class ResourceCreate(BaseModel):
    name: str
    type: str
    capacity_mw: float