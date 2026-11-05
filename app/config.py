from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_token: str = ""
    groq_api_key: str = ""
    # Jedes Modell hat bei Groq ein eigenes Gratis-Kontingent; ist eins ausgelastet
    # oder abgeschaltet, springt das nächste ein (siehe Vault: gratis-llm-apis).
    ki_modelle: list[str] = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "qwen/qwen3.8-27b",
    ]
    katalog_pfad: str = "katalog/katalog.json"
    amazon_tag: str = ""

    # Update per Fingertipp (SideStore-Quelle): beide Werte nur in Render, nie im Repo.
    download_geheimnis: str = ""
    github_token: str = ""
    github_repo: str = "lukaclaude2-star/geschenke-app"
    oeffentliche_url: str = "https://geschenke.onrender.com"

    # Drosselung der KI-Routen je Verbindung (app/drossel.py). Ein Gespräch braucht rund
    # 10 Anfragen, zügiges Wischen etwa 5 pro Minute, ein langer Tag unter 100. Groq gratis hat
    # je Modell nur 1.000 Anfragen und 200.000 Token am Tag für alle zusammen: Eine Verbindung
    # soll davon höchstens einen kleinen Teil verbrauchen können.
    drossel_pro_minute: int = 15
    drossel_pro_tag: int = 200

    # Ramsch-Filter, Stufe 1 und 2
    min_preis: float = 8.0
    min_note: int = 6
    min_beschreibung: int = 60
    min_bildbreite: int = 300


settings = Settings()
