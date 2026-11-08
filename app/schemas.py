from pydantic import BaseModel
from datetime import datetime

class TaskBase(BaseModel):
    title: str
    description: str
    completed: bool = False


class TaskCreate(TaskBase):
    pass 


class Task(TaskBase):
    id: int
    added_at: datetime
    
    class Config:
        orm_mode = True