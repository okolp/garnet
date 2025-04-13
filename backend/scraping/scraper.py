import requests
from bs4 import BeautifulSoup

def extract_raw_text_from_url(url: str) -> str:
    """Fetches the full visible text content from a recipe page."""
    response = requests.get(url)
    response.raise_for_status()
    response.encoding = 'utf-8'

    soup = BeautifulSoup(response.text, "html.parser")

    # Remove script/style and hidden tags
    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()

    # Get visible text
    raw_text = soup.get_text(separator="\n")
    lines = [line.strip() for line in raw_text.splitlines()]
    clean_text = "\n".join(line for line in lines if line)

    return clean_text
