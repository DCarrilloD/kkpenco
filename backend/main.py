from contextlib import asynccontextmanager
from fastapi import FastAPI
from backend.database import init_db
from backend.routers import events, users, chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(
    title="KKCoS API",
    description="Social Poop Tracker API",
    version="0.1.0",
    lifespan=lifespan
)

app.include_router(events.router)
app.include_router(users.router)
app.include_router(chat.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to KKCoS API"}
