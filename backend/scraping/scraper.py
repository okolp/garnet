import requests
from bs4 import BeautifulSoup

def extract_raw_text_and_image(url: str) -> dict:
    """Fetches the full visible text content and main image from a recipe page."""
    response = requests.get(url)
    response.raise_for_status()
    response.encoding = 'utf-8'

    soup = BeautifulSoup(response.text, "html.parser")

    # Remove unwanted tags
    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()

    # ✅ Extract image (Open Graph preferred)
    image_url = None

    og_image = soup.find("meta", property="og:image")
    if og_image and og_image.get("content"):
        image_url = og_image["content"]
    else:
        # Fallback: Try finding an image in the main content
        img = soup.select_one("article img, .recipe img, .post img")
        if img and img.get("src"):
            image_url = img["src"]

    # ✅ Extract clean visible text
    raw_text = soup.get_text(separator="\n")
    lines = [line.strip() for line in raw_text.splitlines()]
    clean_text = "\n".join(line for line in lines if line)

    return {
        "text": clean_text,
        "image_url": image_url
    }
