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



from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from dependencies import get_db
from models.recipe import Recipe as DBRecipe


@router.post("/save")
def save_recipe(recipe: dict, db: Session = Depends(get_db)):
    db_recipe = DBRecipe(
        title=recipe["title"],
        ingredients=recipe["ingredients"],
        steps=recipe["steps"],
        tags=recipe.get("tags", []),
        image_url=recipe.get("image_url"),
    )
    db.add(db_recipe)
    db.commit()
    db.refresh(db_recipe)
    return {"id": db_recipe.id, "message": "Recipe saved successfully"}


from sqlalchemy.orm import Session
from fastapi import Depends
from models.recipe import Recipe as DBRecipe
from dependencies import get_db

@router.get("/")
def get_all_recipes(db: Session = Depends(get_db)):
    recipes = db.query(DBRecipe).all()
    return [
        {
            "id": r.id,
            "title": r.title,
            "ingredients": r.ingredients,
            "steps": r.steps,
            "tags": r.tags,
            "image_url": r.image_url
        }
        for r in recipes
    ]

@router.delete("/{recipe_id}/delete")
def delete_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = db.query(DBRecipe).filter(DBRecipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    db.delete(recipe)
    db.commit()
    return {"message": f"Recipe {recipe_id} deleted successfully"}

from pydantic import BaseModel
from typing import List, Optional

class RecipeUpdateRequest(BaseModel):
    title: str
    ingredients: List[str]
    steps: List[str]
    tags: Optional[List[str]] = []
    image_url: Optional[str] = None

@router.put("/{recipe_id}/edit")
def update_recipe(recipe_id: int, update: RecipeUpdateRequest, db: Session = Depends(get_db)):
    recipe = db.query(DBRecipe).filter(DBRecipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    recipe.title = update.title
    recipe.ingredients = update.ingredients
    recipe.steps = update.steps
    recipe.tags = update.tags
    recipe.image_url = update.image_url

    db.commit()
    db.refresh(recipe)
    return {"message": f"Recipe {recipe_id} updated", "recipe": {
        "id": recipe.id,
        "title": recipe.title,
        "ingredients": recipe.ingredients,
        "steps": recipe.steps,
        "tags": recipe.tags,
        "image_url": recipe.image_url
    }}