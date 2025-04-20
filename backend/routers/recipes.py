from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, HttpUrl
from scraping.scraper import extract_raw_text_and_image
from services.ai_processor import process_recipe_text_with_ai
from dependencies import get_current_user
from models.users import User  # if not already imported
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from dependencies import get_db
from models.recipe import Recipe as DBRecipe


router = APIRouter(prefix="/recipes", tags=["Recipes"])

class RecipeRequest(BaseModel):
    url: HttpUrl

@router.post("/from-url")
def extract_recipe_from_url(
    request: RecipeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)  # Will be None if not authenticated
):
    try:
        scraped = extract_raw_text_and_image(request.url)

        # Use user preferences or defaults
        preferred_language = current_user.preferred_language if current_user else "English"
        preferred_units = current_user.preferred_units if current_user else "metric"

        recipe_data = process_recipe_text_with_ai(
            raw_text=scraped["text"],
            language=preferred_language,
            units=preferred_units
        )

        # Fallback to scraped image if missing
        if not recipe_data.get("image_url") and scraped.get("image_url"):
            recipe_data["image_url"] = scraped["image_url"]

        return {"recipe": recipe_data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




@router.post("/save")
def save_recipe(recipe: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_recipe = DBRecipe(
        title=recipe["title"],
        ingredients=recipe["ingredients"],
        steps=recipe["steps"],
        tags=recipe.get("tags", []),
        image_url=recipe.get("image_url"),
        user_id=current_user.id 
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
def get_all_recipes(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    recipes = db.query(DBRecipe).filter(DBRecipe.user_id == current_user.id).all()
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
def delete_recipe(recipe_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    recipe = db.query(DBRecipe).filter(DBRecipe.id == recipe_id).first()

    if recipe is None:
        raise HTTPException(status_code=404, detail="Recipe not found")

    if recipe.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this recipe")

    db.delete(recipe)
    db.commit()
    return {"message": "Recipe deleted"}


@router.put("/{recipe_id}/edit")
def edit_recipe(recipe_id: int, updated: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    recipe = db.query(DBRecipe).filter(DBRecipe.id == recipe_id).first()

    if recipe is None:
        raise HTTPException(status_code=404, detail="Recipe not found")

    if recipe.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this recipe")

    recipe.title = updated.get("title", recipe.title)
    recipe.ingredients = updated.get("ingredients", recipe.ingredients)
    recipe.steps = updated.get("steps", recipe.steps)
    recipe.tags = updated.get("tags", recipe.tags)
    recipe.image_url = updated.get("image_url", recipe.image_url)

    db.commit()
    db.refresh(recipe)
    return {"message": "Recipe updated"}
