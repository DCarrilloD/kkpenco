from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select, func, desc, asc
from backend.database import get_session
from shared.models import KKEvent, Consistency, User
from datetime import datetime, timezone

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

@router.get("/stats")
def get_stats(session: Session = Depends(get_session)):
    """
    Returns statistics for the Hall of Fame and averages.
    """
    stats = {
        "hall_of_fame": {
            "monstruoso": None, # Max Jurásica
            "escopetas": None,  # Max Espurruteo
            "timido": None      # Min Events
        },
        "averages": []
    }
    
    # 1. Mayor Cagador Monstruoso (Max Jurásica)
    stmt_jurasica = (
        select(User.username, func.count(KKEvent.id).label("count"))
        .join(KKEvent, KKEvent.user_id == User.id)
        .where(KKEvent.consistency == Consistency.JURASICA)
        .group_by(User.username)
        .order_by(desc("count"))
        .limit(1)
    )
    res_jurasica = session.exec(stmt_jurasica).first()
    if res_jurasica:
        stats["hall_of_fame"]["monstruoso"] = {"username": res_jurasica[0], "count": res_jurasica[1]}

    # 2. El Escopetas (Max Espurruteo)
    stmt_espurruteo = (
        select(User.username, func.count(KKEvent.id).label("count"))
        .join(KKEvent, KKEvent.user_id == User.id)
        .where(KKEvent.consistency == Consistency.ESPURRUTEO)
        .group_by(User.username)
        .order_by(desc("count"))
        .limit(1)
    )
    res_espurruteo = session.exec(stmt_espurruteo).first()
    if res_espurruteo:
        stats["hall_of_fame"]["escopetas"] = {"username": res_espurruteo[0], "count": res_espurruteo[1]}

    # 3. El Tímido (Min Events > 0)
    stmt_timido = (
        select(User.username, func.count(KKEvent.id).label("count"))
        .join(KKEvent, KKEvent.user_id == User.id)
        .group_by(User.username)
        .having(func.count(KKEvent.id) > 0)
        .order_by(asc("count"))
        .limit(1)
    )
    res_timido = session.exec(stmt_timido).first()
    if res_timido:
        stats["hall_of_fame"]["timido"] = {"username": res_timido[0], "count": res_timido[1]}

    # 4. Averages
    # We need total count and first event date for each user
    users = session.exec(select(User)).all()
    for user in users:
        # Get count
        count = session.exec(select(func.count(KKEvent.id)).where(KKEvent.user_id == user.id)).one()
        if count > 0:
            # Get first event
            first_event = session.exec(select(KKEvent).where(KKEvent.user_id == user.id).order_by(KKEvent.timestamp.asc()).limit(1)).first()
            if first_event:
                now = datetime.now(timezone.utc)
                # Ensure naive/aware compatibility if needed (assuming UTC for now as per models)
                first_ts = first_event.timestamp
                if first_ts.tzinfo is None:
                    first_ts = first_ts.replace(tzinfo=timezone.utc)
                
                # Calculate Calendar Days Active
                first_date = first_ts.date()
                now_date = now.date()
                
                # Difference in days + 1 (to include the first day)
                days_active = (now_date - first_date).days + 1
                
                # Safety check (should always be >= 1 if logic is correct, but safe > sorry)
                if days_active < 1:
                    days_active = 1
                
                avg = count / days_active
                stats["averages"].append({
                    "username": user.username,
                    "average": round(avg, 2),
                    "days": days_active,
                    "total": count
                })

    return stats

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
