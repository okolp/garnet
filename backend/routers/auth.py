# backend/routers/auth.py

from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from dependencies import get_db, get_current_user
from models.users import User
from auth.auth import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Auth"])


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    preferred_language: str
    preferred_units: str


@router.post("/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    # 1) Check for existing user
    if db.query(User).filter(User.email == req.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # 2) Create & save new user
    new_user = User(
        email=req.email,
        hashed_password=hash_password(req.password),
        preferred_language=req.preferred_language,
        preferred_units=req.preferred_units,
    )
    db.add(new_user)
    db.commit()
    
    # 3) Issue JWT so front‑end can auto‑login
    token = create_access_token({"sub": new_user.email})
    return {"access_token": token, "token_type": "bearer"}



@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    # authenticate
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # issue JWT
    token = create_access_token({"sub": user.email})
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me")
def read_current_user(current_user: User = Depends(get_current_user)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return {
        "email": current_user.email,
        "preferred_language": current_user.preferred_language,
        "preferred_units": current_user.preferred_units,
    }