# Geschenke-App

Persönliche Geschenke per Gespräch und Wischen finden. Design und Plan unter `docs/`,
Grundbausteine in `CLAUDE.md`.

- Server: `app/` (FastAPI), Tests: `.venv/Scripts/python -m pytest -q`
- Katalog bauen: `python scripts/build_katalog.py` (braucht `GROQ_API_KEY`)
- iPhone-App: `ios/` (XcodeGen, Build über GitHub Actions, Installation per SideStore)
