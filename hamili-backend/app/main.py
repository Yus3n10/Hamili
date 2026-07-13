from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core.config import get_settings
from app.core.rate_limit import limiter
from app.routers import analytics, auth, budgets, categories, chat, goals, insights, recurring, transactions

settings = get_settings()

# Reject request bodies larger than this before they are parsed (defense against
# oversized/malicious payloads). All Hamili endpoints exchange small JSON.
_MAX_BODY_BYTES = 512 * 1024

app = FastAPI(
    title="Hamili API",
    description="Backend for Hamili — AI-powered personal finance tracker.",
    version="0.1.0",
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)


@app.middleware("http")
async def limit_body_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length is not None and content_length.isdigit() and int(content_length) > _MAX_BODY_BYTES:
        return JSONResponse(status_code=413, content={"detail": "Request body too large."})
    return await call_next(request)


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
app.include_router(analytics.router)
app.include_router(insights.router)
app.include_router(chat.router)
# Milestone 4+: recurring, analytics routers plug in the same way — each
# is self-contained, so this file stays a thin registry.


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok"}
