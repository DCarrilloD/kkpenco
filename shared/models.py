from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from sqlmodel import Field, SQLModel, Relationship

class ChatMessage(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id") # Note: table name is users
    content: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    user: Optional["User"] = Relationship()

class Consistency(str, Enum):
    """
    Enumeración que define los tipos de consistencia de una deposición.
    """
    NORMAL = "Normal"
    JURASICA = "Jurásica"
    ESPURRUTEO = "Espurruteo"

class KKEvent(SQLModel, table=True):
    """
    Modelo que representa un evento de deposición (una 'caca').
    
    Attributes:
        id: Identificador único del evento.
        user_id: ID del usuario que creó el evento.
        group_id: ID del grupo al que pertenece el evento (opcional).
        timestamp: Fecha y hora exacta del evento.
        duration: Duración del evento en segundos (opcional).
        consistency: Tipo de consistencia de la deposición.
        notes: Notas adicionales o observaciones (opcional).
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    group_id: Optional[int] = Field(default=None, index=True)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    duration: Optional[int] = Field(default=None)
    consistency: Consistency
    notes: Optional[str] = Field(default=None)

class User(SQLModel, table=True):
    __tablename__ = "users"
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    email: str = Field(index=True, unique=True)
    password_hash: str

class UserCreate(SQLModel):
    username: str
    email: str
    password: str

class UserLogin(SQLModel):
    username: str
    password: str

class UserRead(SQLModel):
    id: int
    username: str

