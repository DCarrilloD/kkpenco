from sqlmodel import Session, SQLModel, create_engine
from shared.models import KKEvent, Consistency
from datetime import datetime
import os

# Setup simpler DB for test
DATABASE_URL = "sqlite:///./test_debug.db"
engine = create_engine(DATABASE_URL, echo=True)

def init_db():
    SQLModel.metadata.create_all(engine)

def test_insert():
    init_db()
    with Session(engine) as session:
        print("Creating event...")
        try:
            event = KKEvent(
                user_id=1,
                consistency=Consistency.NORMAL,
                notes="Test note",
                timestamp=datetime.utcnow()
            )
            print(f"Event object: {event}")
            session.add(event)
            session.commit()
            print("Event saved successfully!")
            session.refresh(event)
            print(f"Event ID: {event.id}")
        except Exception as e:
            print("CRASHED!")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    if os.path.exists("test_debug.db"):
        os.remove("test_debug.db")
    test_insert()
