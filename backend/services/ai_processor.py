import google.generativeai as genai
import os

# Load your API key
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
genai.configure(api_key=GOOGLE_API_KEY)

# Use Gemini Pro (text-only for now)
model = genai.GenerativeModel("gemini-pro")

PROMPT_TEMPLATE = """
You will be given raw text content scraped from a coking recipe webpage.
Your job is to extract the structured recipe data from it.

Respond in JSON format with the following fields:
- title (string)
- ingredients (list of short strings)
- steps (list of short strings, each step is a single action)
- tags (list of 3-5 short keywords like "breakfast", "vegan", etc.)
- image_url (string or null if unavailable)

Here is the recipe content:
---
{text}
---
Now respond only with the valid JSON.
"""

def process_recipe_text_with_ai(raw_text: str) -> dict:
    """Use Gemini to extract structured recipe info from raw web text."""
    prompt = PROMPT_TEMPLATE.format(text=raw_text[:3000])  # safety trim
    try:
        response = model.generate_content(prompt)
        return response.candidates[0].content.parts[0].text  # raw JSON
    except Exception as e:
        print(f"[AI ERROR] {e}")
        raise RuntimeError("AI model failed to process the recipe.")
