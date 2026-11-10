from fastapi.testclient import TestClient
from app.main import app
from app.config import settings
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import get_db, Base
from  app.models import Task
import pytest


DB_URL = f"postgresql+psycopg://{settings.database_username}:{settings.database_password}@{settings.database_hostname}:{settings.database_port}/{settings.database_name}_test"

engine = create_engine(DB_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture
def session():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(session):
    def override_get_db():
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)


@pytest.fixture
def test_tasks(session):
    task_data = [
        {
            "title": "Buy groceries",
            "description": "Milk, eggs, and bread",
            "completed": False,
        },
        {
            "title": "Finish FastAPI course",
            "description": "Complete the testing section",
            "completed": True,
        },
        {
            "title": "Set up Docker",
            "description": "Containerize the task tracker app",
            "completed": False,
        },
        {
            "title": "Study for AWS exam",
            "description": "Review VPC and networking topics",
            "completed": False,
        },
        {
            "title": "Update resume",
            "description": "Add the task tracker project",
            "completed": True,
        },
        {
            "title": "Apply to help desk roles",
            "description": "Send three applications this week",
            "completed": False,
        },
    ]

    def create_task_model(task):
        return Task(**task)

    tasks = list(map(create_task_model, task_data))

    session.add_all(tasks)
    session.commit()
    return session.query(Task).order_by(Task.id).all()

    
