from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routers import auth, budgets, categories, chat, goals, recurring, transactions

settings = get_settings()

app = FastAPI(
    title="Hamili API",
    description="Backend for Hamili — AI-powered personal finance tracker.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(budgets.router)
app.include_router(goals.router)
app.include_router(recurring.router)
app.include_router(chat.router)
# Milestone 4+: recurring, analytics routers plug in the same way — each
# is self-contained, so this file stays a thin registry.


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok"}
