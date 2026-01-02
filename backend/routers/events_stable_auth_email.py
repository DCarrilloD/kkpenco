from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select, func
from backend.database import get_session
from shared.models import KKEvent

router = APIRouter(
    prefix="/events",
    tags=["events"],
    responses={404: {"description": "Not found"}},
)

@router.get("/ranking")
def get_ranking(session: Session = Depends(get_session)):
    print("DEBUG: Executing get_ranking with username")
    """
    Devuelve el ranking de usuarios con más eventos, incluyendo el nombre de usuario.
    """
    # Importar User aquí para asegurar visibilidad, aunque ya debería estar en los modelos
    from shared.models import User
    
    # Query: Select User.username, Count(KkEvent.id)
    # Join KKEvent with User
    # Group by User.username
    statement = (
        select(User.username, func.count(KKEvent.id).label("count"))
        .join(KKEvent, KKEvent.user_id == User.id)
        .group_by(User.username)
        .order_by(func.count(KKEvent.id).desc())
    )
    
    results = session.exec(statement).all()
    
    # Convertir a lista de diccionarios para JSON
    ranking_data = [{"username": r[0], "count": r[1]} for r in results]
    
    return ranking_data

@router.post("/", response_model=KKEvent)
def create_event(event: KKEvent, session: Session = Depends(get_session)):
    try:
        # Patch for SQLite/Pydantic DateTime issue
        if isinstance(event.timestamp, str):
            from datetime import datetime
            event.timestamp = datetime.fromisoformat(event.timestamp)
        
        # Ensure naive datetime (remove timezone if any) for SQLite compatibility
        if event.timestamp.tzinfo is not None:
             event.timestamp = event.timestamp.replace(tzinfo=None)
            
        session.add(event)
        session.commit()
        session.refresh(event)
        return event
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise e

@router.get("/", response_model=List[KKEvent])
def read_events(offset: int = 0, limit: int = 100, session: Session = Depends(get_session)):
    events = session.exec(select(KKEvent).offset(offset).limit(limit)).all()
    return events

@router.get("/{event_id}", response_model=KKEvent)
def read_event(event_id: int, session: Session = Depends(get_session)):
    event = session.get(KKEvent, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@router.delete("/{event_id}")
def delete_event(event_id: int, session: Session = Depends(get_session)):
    event = session.get(KKEvent, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    session.delete(event)
    session.commit()
    return {"ok": True}
