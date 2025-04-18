from database import Base, engine
from models.users import User
from models.recipe import Recipe  # include any others

Base.metadata.create_all(bind=engine)
print("✅ All tables created successfully.")
