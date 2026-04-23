# backend/app/api/routes/municipalities.py
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.municipality import Municipality
from app.models.citizen import Citizen
from app.schemas.municipality_schema import MunicipalityCreate, MunicipalityResponse, MunicipalityUpdate
from app.api.deps import get_current_admin

router = APIRouter()

@router.post("/", response_model=MunicipalityResponse, status_code=status.HTTP_201_CREATED)
def add_new_municipality(
    muni_data: MunicipalityCreate,
    db: Session = Depends(get_db),
    current_admin: Citizen = Depends(get_current_admin) # Sadece admin girebilir
):
    # 1. AYNI İSİMDE BELEDİYE VAR MI KONTROLÜ
    existing_muni = db.query(Municipality).filter(Municipality.name == muni_data.name).first()
    if existing_muni:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu belediye zaten sisteme kayıtlı."
        )

    # 2. YENİ BELEDİYEYİ OLUŞTUR
    new_municipality = Municipality(
        id=str(uuid.uuid4()),
        name=muni_data.name,
        officialEmail=muni_data.officialEmail
    )

    try:
        db.add(new_municipality)
        db.commit()
        db.refresh(new_municipality)
        return new_municipality
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Veritabanı hatası: {str(e)}")

@router.patch("/{municipality_id}", response_model=MunicipalityResponse)
def update_municipality(
    municipality_id: uuid.UUID,
    update_data: MunicipalityUpdate,
    db: Session = Depends(get_db),
    current_admin: Citizen = Depends(get_current_admin) # Sadece admin girebilir
):
    # 1. BELEDİYEYİ BUL
    db_muni = db.query(Municipality).filter(Municipality.id == str(municipality_id)).first()

    if not db_muni:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Belediye bulunamadı.")

    # 2. VERİLERİ GÜNCELLE
    update_dict = update_data.model_dump(exclude_unset=True)

    for key, value in update_dict.items():
        setattr(db_muni, key, value)

    try:
        db.commit()
        db.refresh(db_muni)
        return db_muni
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Güncelleme hatası: {str(e)}")

@router.get("/", response_model=list[MunicipalityResponse])
def get_all_municipalities(
    db: Session = Depends(get_db),
    current_admin: Citizen = Depends(get_current_admin) # Sadece admin girebilir
):
    return db.query(Municipality).all()