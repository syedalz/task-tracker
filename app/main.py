from fastapi import FastAPI, Response, status, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import List
from . import models, schemas
from .database import engine, get_db
from .routers import task

models.Base.metadata.create_all(bind=engine)

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(task.router  )

@app.get("/")
def root():
    return {"message": "Welcome to Task Manager!"}
