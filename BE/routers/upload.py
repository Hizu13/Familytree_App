from fastapi import APIRouter, UploadFile, File, HTTPException
import shutil
import os
import uuid
from typing import Optional

router = APIRouter(prefix="/upload", tags=["Upload"])

UPLOAD_DIR = "static/uploads"

# Ensure directory exists
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/image")
async def upload_image(file: UploadFile = File(...)):
    try:
        # Validate file type (basic)
        if not file.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File must be an image")

        # Generate unique filename
        file_ext = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(UPLOAD_DIR, unique_filename)

        # Save file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Return relative URL (assuming app is served at root or handles /static)
        # Note: In production, this should include full domain or be handled by Nginx
        # For local dev: http://localhost:8000/static/uploads/...
        return {
            "url": f"/static/uploads/{unique_filename}",
            "filename": unique_filename
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not upload file: {str(e)}")
