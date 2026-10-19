from fastapi import FastAPI
from fastapi.params import Body
from pydantic import BaseModel

app = FastAPI()

class Task(BaseModel):
    title: str
    description: str
    completed: bool



@app.get("/")
def root():
    return {"message": "Hello boy"}

@app.post("/upload_task")
def upload_task(new_task: Task):
    print(new_task)
    return {"task": "new task"}

    