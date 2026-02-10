from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import List, Dict
import json
from datetime import datetime
from db.mysql_connection import get_db
from models import Message, User
from schemas import MessageRead
from dependencies import serializer, SESSION_EXPIRE_SECONDS
from itsdangerous import SignatureExpired, BadSignature

router = APIRouter(
    prefix="/families",
    tags=["chat"]
)

class ConnectionManager:
    def __init__(self):
        # family_id -> List[WebSocket]
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, family_id: int):
        await websocket.accept()
        if family_id not in self.active_connections:
            self.active_connections[family_id] = []
        self.active_connections[family_id].append(websocket)
        print(f"WS Connected to family {family_id}. Total: {len(self.active_connections[family_id])}")

    def disconnect(self, websocket: WebSocket, family_id: int):
        if family_id in self.active_connections:
            if websocket in self.active_connections[family_id]:
                self.active_connections[family_id].remove(websocket)
                if not self.active_connections[family_id]:
                    del self.active_connections[family_id]
            print(f"WS Disconnected from family {family_id}")

    async def broadcast(self, message: dict, family_id: int):
        if family_id in self.active_connections:
            # Copy list to avoid modification during iteration issues
            connections = list(self.active_connections[family_id])
            for connection in connections:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    print(f"Error sending message: {e}")
                    # Could optionally remove dead connection here

manager = ConnectionManager()

def get_user_from_token(token: str, db: Session):
    try:
        # Debugging
        print(f"Attempting to verify token: {token[:10]}...") 
        data = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
        user = db.query(User).filter(User.id == data["user_id"]).first()
        if user:
            print(f"User verified: {user.username}")
        else:
            print("User not found in DB")
        return user
    except SignatureExpired:
        print("Token expired")
        return None
    except BadSignature as e:
        print(f"Bad Signature: {e}")
        return None
    except Exception as e:
        print(f"Token verification error: {e}")
        return None

@router.websocket("/{family_id}/chat")
async def websocket_endpoint(
    websocket: WebSocket, 
    family_id: int, 
    token: str = Query(...),
    db: Session = Depends(get_db)
):
    # Authenticate
    user = get_user_from_token(token, db)
    if not user:
        await websocket.close(code=4001, reason="Unauthorized/Invalid Token")
        return

    # TODO: Verify user belongs to family_id (Optional but recommended)
    
    await manager.connect(websocket, family_id)
    try:
        while True:
            data = await websocket.receive_text() # Client sends JSON string
            print(f"Received WS data: {data}")
            try:
                message_data = json.loads(data)
                
                # Save to DB
                content = message_data.get("content")
                msg_type = message_data.get("message_type", "text")
                
                if content:
                    print("Saving message to DB...")
                    new_msg = Message(
                        family_id=family_id,
                        sender_id=user.id,
                        content=content,
                        message_type=msg_type,
                        created_at=datetime.utcnow()
                    )
                    db.add(new_msg)
                    db.commit()
                    db.refresh(new_msg)
                    print(f"Message saved with ID: {new_msg.id}")
                    
                    # Prepare payload
                    # sender_data for UI
                    response_data = {
                        "id": new_msg.id,
                        "family_id": new_msg.family_id,
                        "sender_id": new_msg.sender_id,
                        "content": new_msg.content,
                        "created_at": new_msg.created_at.isoformat(),
                        "message_type": new_msg.message_type,
                        "sender_name": f"{user.first_name or ''} {user.last_name or ''}".strip() or user.username,
                        # "sender_avatar": user.avatar_url # If User had avatar
                        "author": {
                            "id": str(user.id),
                            "firstName": user.first_name,
                            "lastName": user.last_name,
                            "imageUrl": None # Placeholder
                        }
                    }
                    
                    print(f"Broadcasting message to family {family_id}")
                    await manager.broadcast(response_data, family_id)
            except Exception as e:
                print(f"Error processing message: {e}")
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, family_id)
    except Exception as e:
        print(f"WebSocket Error: {e}")
        manager.disconnect(websocket, family_id)


@router.get("/{family_id}/chat/messages", response_model=List[MessageRead])
def get_chat_history(
    family_id: int, 
    limit: int = 50, 
    skip: int = 0, 
    db: Session = Depends(get_db)
):
    messages = db.query(Message)\
        .filter(Message.family_id == family_id)\
        .order_by(Message.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()
    
    # Enrich with sender info
    result = []
    # Fetch all senders in batch or one by one (optimization opportunity)
    # For now, simplistic loop (N+1 query but limit is 50, acceptable for prototype)
    for msg in messages:
        sender = msg.sender
        sender_name = f"{sender.first_name or ''} {sender.last_name or ''}".strip() or sender.username
        
        result.append(MessageRead(
            id=msg.id,
            family_id=msg.family_id,
            sender_id=msg.sender_id,
            content=msg.content,
            created_at=msg.created_at.isoformat(),
            message_type=msg.message_type,
            sender_name=sender_name
        ))
    
    return result
