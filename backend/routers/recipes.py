from typing import List, Optional

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, HttpUrl
from sqlalchemy import or_, cast, String
from sqlalchemy.orm import Session

from scraping.scraper import extract_raw_text_and_image
from services.ai_processor import process_recipe_text_with_ai
from dependencies import get_db, get_current_user
from models.users import User
from models.recipe import Recipe as DBRecipe
from fastapi import UploadFile, File
from services.ai_processor import process_recipe_image_with_ai

router = APIRouter(prefix="/recipes", tags=["Recipes"])


class RecipeRequest(BaseModel):
    url: HttpUrl


@router.post("/from-url")
def extract_recipe_from_url(
    request: RecipeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),  # Will be None if not authenticated
):
    try:
        scraped = extract_raw_text_and_image(request.url)

        # Use user preferences or defaults
        preferred_language = current_user.preferred_language if current_user else "English"
        preferred_units = current_user.preferred_units if current_user else "metric"

        recipe_data = process_recipe_text_with_ai(
            raw_text=scraped["text"],
            language=preferred_language,
            units=preferred_units,
        )

        # Fallback to scraped image if missing
        if not recipe_data.get("image_url") and scraped.get("image_url"):
            recipe_data["image_url"] = scraped["image_url"]

        return {"recipe": recipe_data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save")
def save_recipe(
    recipe: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db_recipe = DBRecipe(
        title=recipe["title"],
        ingredients=recipe["ingredients"],
        steps=recipe["steps"],
        tags=recipe.get("tags", []),
        image_url=recipe.get("image_url"),
        user_id=current_user.id,
    )
    db.add(db_recipe)
    db.commit()
    db.refresh(db_recipe)
    return {"id": db_recipe.id, "message": "Recipe saved successfully"}


@router.get("/", response_model=List[dict])
def get_all_recipes(
    q:    Optional[str]          = Query(None),
    tags: Optional[List[str]]   = Query(None),
    skip: int                   = Query(0, ge=0),
    limit: int                  = Query(100, ge=1, le=500),
    db:   Session               = Depends(get_db),
    current_user: User          = Depends(get_current_user),
):
    query = db.query(DBRecipe).filter(DBRecipe.user_id == current_user.id)

    if q:
        pat = f"%{q}%"
        query = query.filter(
            or_(
                DBRecipe.title.ilike(pat),
                cast(DBRecipe.ingredients, String).ilike(pat),
            )
        ).order_by(DBRecipe.title.ilike(pat).desc())

    if tags:
        # JSONB @> array containment: all elements in `tags` must be present
        query = query.filter(DBRecipe.tags.contains(tags))

    recipes = query.offset(skip).limit(limit).all()

    return [
        {
            "id": r.id,
            "title": r.title,
            "ingredients": r.ingredients,
            "steps": r.steps,
            "tags": r.tags,
            "image_url": r.image_url,
        }
        for r in recipes
    ]

@router.delete("/{recipe_id}/delete")
def delete_recipe(
    recipe_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    recipe = db.query(DBRecipe).filter(DBRecipe.id == recipe_id).first()

    if recipe is None:
        raise HTTPException(status_code=404, detail="Recipe not found")

    if recipe.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this recipe")

    db.delete(recipe)
    db.commit()
    return {"message": "Recipe deleted"}


@router.put("/{recipe_id}/edit")
def edit_recipe(
    recipe_id: int,
    updated: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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

@router.post("/from-image")
async def extract_recipe_from_image(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Accepts a recipe photo upload, runs a Gemini multimodal model
    to extract structured recipe data, then returns it.
    """
    try:
        # Read image bytes
        contents = await image.read()

        # Call your new AI helper (see below)
        recipe_data = process_recipe_image_with_ai(
            image_bytes=contents,
            language=current_user.preferred_language if current_user else "English",
            units=current_user.preferred_units if current_user else "metric"
        )

        # Fallback: if AI didn’t pick up an image_url, attach one (optional)
        # recipe_data["image_url"] = recipe_data.get("image_url") or save_to_storage(contents)

        # Save to DB exactly like /save
        db_recipe = DBRecipe(
            title=recipe_data["title"],
            ingredients=recipe_data["ingredients"],
            steps=recipe_data["steps"],
            tags=recipe_data.get("tags", []),
            image_url=recipe_data.get("image_url"),
            user_id=current_user.id,
        )
        db.add(db_recipe)
        db.commit()
        db.refresh(db_recipe)

        return {"id": db_recipe.id, "recipe": recipe_data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image processing failed: {e}")