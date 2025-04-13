from fastapi import FastAPI
from routers import recipes

app = FastAPI()
app.include_router(recipes.router)

@app.get("/")
def root():
    return {"message": "Backend running"}

from database import Base, engine
from models.recipe import Recipe

Base.metadata.create_all(bind=engine)
