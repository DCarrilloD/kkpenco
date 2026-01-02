import os
from sqlmodel import SQLModel, create_engine, Session
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL no está definida en las variables de entorno.")

engine = create_engine(DATABASE_URL, echo=True)

def init_db():
    # Importar modelos aquí para asegurarse de que estén registrados en metadata
    from shared.models import KKEvent, User
    SQLModel.metadata.create_all(engine)

def get_session():
    with Session(engine) as session:
        yield session
