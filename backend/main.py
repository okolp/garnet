from fastapi import FastAPI
from routers import recipes
from fastapi.middleware.cors import CORSMiddleware  # ✅ needs to be here


app = FastAPI()
app.include_router(recipes.router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can restrict to your dev domain later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "Backend running"}
