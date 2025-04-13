# backend/models/recipe.py
from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.dialects.postgresql import ARRAY
from database import Base

class Recipe(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    ingredients = Column(ARRAY(Text), nullable=False)
    steps = Column(ARRAY(Text), nullable=False)
    tags = Column(ARRAY(String), nullable=True)
    image_url = Column(String, nullable=True)
