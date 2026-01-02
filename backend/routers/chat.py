from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlmodel import Session, select, desc
from backend.database import get_session
from shared.models import ChatMessage, User
from datetime import datetime, timezone

router = APIRouter(
    prefix="/chat",
    tags=["chat"],
    responses={404: {"description": "Not found"}},
)

@router.get("/messages", response_model=List[Dict[str, Any]])
def get_messages(session: Session = Depends(get_session), limit: int = 50):
    # Fetch last N messages, ordered by timestamp desc
    statement = select(ChatMessage, User).join(User).order_by(desc(ChatMessage.timestamp)).limit(limit)
    results = session.exec(statement).all()
    
    messages = []
    # Reverse to show oldest first in the list (chronological)
    for message, user in reversed(results):
        messages.append({
            "id": message.id,
            "user_id": message.user_id,
            "username": user.username,
            "content": message.content,
            "timestamp": message.timestamp.isoformat()
        })
        
    return messages

@router.post("/message")
def send_message(
    user_id: int = Body(...),
    content: str = Body(...),
    session: Session = Depends(get_session)
):
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    message = ChatMessage(user_id=user_id, content=content)
    session.add(message)
    session.commit()
    session.refresh(message)
    return {"status": "ok", "message_id": message.id}
