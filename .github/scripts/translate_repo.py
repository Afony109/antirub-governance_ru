import os
import fnmatch
from pathlib import Path
from openai import OpenAI

OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]
MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

client = OpenAI(api_key=OPENAI_API_KEY)

PROMPT_EN = """You are a professional translator.
Translate the text from Russian to English.

Style: neutral, factual, concise.
Do not add opinions.
Do not remove or add facts.
Preserve formatting, links, and hashtags.
Return ONLY the translated text."""
PROMPT_UA = """Ти професійний перекладач.
Переклади текст з російської на українську.

Стиль: нейтральний, фактологічний, стриманий.
Без русизмів.
Не додавай і не прибирай факти.
Збережи форматування, посилання та хештеги.
Поверни ЛИШЕ перекладений текст."""

# Что переводим
INCLUDE = ["*.md", "*.mdx", "*.txt"]

# Что исключаем
EXCLUDE_DIRS = {".git", ".github", "node_modules", "venv", "__pycache__", "out"}

ROOT = Path(".").resolve()
OUT_EN = ROOT / "out" / "en"
OUT_UA = ROOT / "out" / "ua"

def should_include(path: Path) -> bool:
    if any(part in EXCLUDE_DIRS for part in path.parts):
        return False
    return any(fnmatch.fnmatch(path.name, pat) for pat in INCLUDE)

def translate(text: str, system_prompt: str) -> str:
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text},
        ],
        temperature=0.2,
    )
    return (resp.choices[0].message.content or "").strip()

def write_out(src: Path, out_root: Path, text: str) -> None:
    rel = src.relative_to(ROOT)
    dst = out_root / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding="utf-8")

def main() -> None:
    OUT_EN.mkdir(parents=True, exist_ok=True)
    OUT_UA.mkdir(parents=True, exist_ok=True)

    files = [p for p in ROOT.rglob("*") if p.is_file() and should_include(p)]
    print(f"Found {len(files)} files to translate")

    for f in files:
        ru = f.read_text(encoding="utf-8")
        en = translate(ru, PROMPT_EN)
        ua = translate(ru, PROMPT_UA)
        write_out(f, OUT_EN, en)
        write_out(f, OUT_UA, ua)

    print("Done.")

if __name__ == "__main__":
    main()
