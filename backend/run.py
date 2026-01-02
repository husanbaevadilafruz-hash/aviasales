"""
run.py - Script to run the FastAPI application

This is the entry point for running the backend server.
Usage: python run.py
Or: uvicorn app.main:app --reload
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )







