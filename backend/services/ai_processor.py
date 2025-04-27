import os
import google.generativeai as genai
import json
import re
import io
from PIL import Image
from dotenv import load_dotenv

load_dotenv()
# Securely load your API key from an environment variable
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

if not GOOGLE_API_KEY:
    raise RuntimeError("GOOGLE_API_KEY is not set")

# Initialize Gemini client
# Use genai.configure instead of genai.Client directly, and specify the API key there.
genai.configure(api_key=GOOGLE_API_KEY)

MODEL_NAME = "gemini-1.5-pro-latest"  # or another appropriate model
PROMPT_TEMPLATE = """
You are a helpful assistant designed to extract structured recipe data from raw text.

Here's how you should operate:

1.  **Analyze the Input:** You will be given the raw text of a cooking recipe which was scraped from the website.  This text may contain a lot of noise, various formatting elements like headings, lists, and other markup. It also could be in a language other than english.
2.  **Extract Recipe Data:**  Your task is to extract the following fields from the recipe text:
    *   `title` (string): The title of the recipe.
    *   `ingredients` (list of strings): A list of ingredients required for the recipe.  Each ingredient should be a short, descriptive string.
    *   `steps` (list of strings): A list of steps to prepare the recipe. Each step should be a short, concise instruction. Each step is one action.
    *   `tags` (list of strings): A list of 3 keywords or tags that describe the recipe, must be from the list provided below. They must be accurate and make sense. Start with capital letters.
    *   `image_url` (string, optional): If the recipe text includes a URL to an image of the finished dish, extract it. If there is no image URL, set this to `null`.


3.  **Output JSON Only:** Your response MUST be a valid JSON object representing the extracted recipe data.  Do NOT include any introductory text, explanations, or other extraneous content. Do NOT include any markdown formatting (e.g., code blocks). Return ONLY the JSON.

4.  **Example Output:**
    ```
    {{
      "title": "Example Recipe",
      "ingredients": [
        "1 cup flour",
        "1/2 cup sugar",
        "1 egg",
        "1/4 cup milk"
      ],
      "steps": [
        "Mix flour and sugar.",
        "Add egg and milk.",
        "Bake at 350F for 20 minutes."
      ],
      "tags": [
        "Breakfast",
        "Vegetarian",
        "Italian"
      ],
      "image_url": null
    }}
    ```

5. list of tags: Breakfast, Brunch, Lunch, Dinner, Snack, Appetizer, Dessert, Drink, Soup, Salad, Italian, Mexican, Chinese, Japanese, Thai, Indian, Middle Eastern, Greek, Korean, Spanish, Vietnamese, Polish, Turkish, Vegetarian, Vegan.

Here is the content:
---
{text}
---
"""

def clean_gemini_output(text: str) -> str:
    # Remove Markdown JSON block formatting (```json ... ```)
    if text.startswith("```"):
        return re.sub(r"^```(?:json)?\n|\n```$", "", text.strip(), flags=re.IGNORECASE)
    return text

def process_recipe_text_with_ai(raw_text: str, language: str = "English", units: str = "metric") -> dict:
    dynamic_instructions = f"""
6.  **Translate & Convert:**
    - Translate the recipe and tags into **{language}**.
    - Convert ingredient measurements to **{units}** units (e.g., grams/milliliters or ounces/cups).
    - Be accurate and culturally appropriate where possible.
    """

    prompt = PROMPT_TEMPLATE.replace(
        "Here is the content:",
        f"{dynamic_instructions}\n\nHere is the content:"
    ).format(text=raw_text)

    try:
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)

        raw_json = clean_gemini_output(response.text.strip())

        try:
            recipe_data = json.loads(raw_json)
            return recipe_data

        except json.JSONDecodeError as e:
            print(f"[JSON ERROR] Failed to decode JSON: {e}")
            print(f"Raw JSON received:\n{raw_json}")
            raise RuntimeError("AI returned invalid JSON")

    except Exception as e:
        print(f"[AI ERROR] {e}")
        raise RuntimeError("AI processing failed")

def process_recipe_image_with_ai(
    image_bytes: bytes,
    language: str = "English",
    units: str = "metric"
) -> dict:
    # 1) Prepare dynamic instructions exactly as in text flow
    dynamic = f"""
6.  **Translate & Convert:**
    - Translate into **{language}**.
    - Convert measurements to **{units}**.
"""
    prompt = PROMPT_TEMPLATE.replace(
        "Here is the content:",
        f"{dynamic}\n\nHere is the image:"
    ).format(text="<see image>")  # we signal the model to look at the image

    # 2) Load the image into a Pillow Image
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    # 3) Call Gemini, passing [prompt, img] as multimodal input
    model = genai.GenerativeModel(MODEL_NAME)
    response = model.generate_content([prompt, img])

    # 4) Strip any markdown fences and parse JSON
    raw = clean_gemini_output(response.text.strip())
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[JSON ERROR]\n{raw}")
        raise RuntimeError("AI returned invalid JSON")