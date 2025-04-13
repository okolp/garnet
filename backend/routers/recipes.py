from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, HttpUrl

from scraping.scraper import extract_raw_text_from_url
from services.ai_processor import process_recipe_text_with_ai

router = APIRouter(prefix="/recipes", tags=["Recipes"])

class RecipeRequest(BaseModel):
    url: HttpUrl

@router.post("/from-url")
def extract_recipe_from_url(request: RecipeRequest):
    try:
        raw_text = extract_raw_text_from_url(request.url)
        recipe_data = process_recipe_text_with_ai(raw_text)
        return {"recipe": recipe_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
