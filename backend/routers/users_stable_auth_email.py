from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from backend.database import get_session
from backend.auth import get_password_hash, verify_password
from shared.models import User, UserCreate, UserLogin, UserRead

router = APIRouter(
    prefix="/users",
    tags=["users"],
    responses={404: {"description": "Not found"}},
)

import re

@router.post("/register", response_model=UserRead)
def register(user: UserCreate, session: Session = Depends(get_session)):
    # Validate email format
    email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    if not re.match(email_regex, user.email):
        raise HTTPException(status_code=400, detail="Invalid email format")

    # Check username
    statement = select(User).where(User.username == user.username)
    if session.exec(statement).first():
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Check email
    statement_email = select(User).where(User.email == user.email)
    if session.exec(statement_email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = get_password_hash(user.password)
    db_user = User(username=user.username, email=user.email, password_hash=hashed_password)
    session.add(db_user)
    session.commit()
    session.refresh(db_user)
    return db_user

@router.post("/recover-password")
def recover_password(email: str, session: Session = Depends(get_session)):
    statement = select(User).where(User.email == email)
    user = session.exec(statement).first()
    
    if user:
        # Simulate sending email
        print(f"========================================")
        print(f" [MOCK EMAIL] To: {email}")
        print(f" Subject: Password Recovery")
        print(f" Body: Hello {user.username}, please reset your password here: http://app/reset?token=12345")
        print(f"========================================")
        return {"message": "Recovery email sent (check console)"}
    else:
        # For security, don't reveal if user exists, or do, depending on requirement. 
        # Standard is usually "If email exists..." or generic message.
        return {"message": "If this email is registered, you will receive instructions."}

@router.post("/login")
def login(user: UserLogin, session: Session = Depends(get_session)):
    statement = select(User).where(User.username == user.username)
    db_user = session.exec(statement).first()
    if not db_user or not verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
    return {"user_id": db_user.id, "username": db_user.username}

@router.get("/", response_model=List[UserRead])
def read_users(session: Session = Depends(get_session)):
    users = session.exec(select(User)).all()
    return users
