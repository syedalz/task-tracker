from fastapi import FastAPI, Response, status, HTTPException
from pydantic import BaseModel
from random import randrange

app = FastAPI()

class Task(BaseModel):
    title: str
    description: str
    completed: bool = False

my_tasks = []

def find_task(id):
    for t in my_tasks:
        if "id" in t and t["id"] == id:
            return t

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "Welcome to Task Manager!"}

@app.get("/tasks")
def get_all_tasks():
    return {"data": my_tasks}

@app.post("/tasks", status_code=status.HTTP_201_CREATED)
def create_task(task: Task):
    task_dict = task.model_dump()
    task_dict['id'] = randrange(0, 10000000)
    my_tasks.append(task_dict)
    return {"task_details": task_dict}

@app.get("/tasks/newest")
def get_newest_task():
    newest_task = my_tasks[-1]
    return {"task_details": newest_task}

@app.get("/tasks/{id}")
def get_task(id: int):
    task = find_task(id)

    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {id} was not found"
        )

    return {"task_details": task}