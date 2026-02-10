from enum import Enum
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import date


# ----------------------------
# Enum cho Role
# ----------------------------
class UserRole(str, Enum):
    admin = "admin"
    editor = "editor"
    member = "member"


# ----------------------------
# User Schemas
# ----------------------------
class UserBase(BaseModel):
    username: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: EmailStr
    cccd: Optional[str] = None # Added
    role: UserRole


class UserCreate(UserBase):
    password: str
    pass


class UserUpdate(BaseModel):
    username: Optional[str] = None
    password: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: Optional[EmailStr] = None
    cccd: Optional[str] = None # Added
    role: Optional[UserRole] = None

# ... (skip to ProfileUpdateRequest)

class ProfileUpdateRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: Optional[str] = None
    cccd: Optional[str] = None # Added



class UserOut(UserBase):
    id: int

    class Config:
        from_attributes = True


# ----------------------------
# Person Schemas
# ----------------------------
class PersonBase(BaseModel):
    cccd: Optional[str] = None
    first_name: str
    last_name: Optional[str] = None
    gender: str
    date_of_birth: Optional[date] = None
    date_of_death: Optional[date] = None
    place_of_birth: Optional[str] = None
    avatar_url: Optional[str] = None
    biography: Optional[str] = None
    father_id: Optional[int] = None
    mother_id: Optional[int] = None
    family_id: Optional[int] = None


class PersonCreate(PersonBase):
    is_father_of_id: Optional[int] = None
    is_mother_of_id: Optional[int] = None
    spouse_id: Optional[int] = None


class PersonUpdate(PersonBase):
    pass


class PersonRead(PersonBase):
    id: int
    role: Optional[str] = "member"
    user_id: Optional[int] = None

    class Config:
        from_attributes = True


# --- Tree Visualization Schemas ---
class TreeNode(BaseModel):
    id: int
    name: str # Full name
    gender: str
    birth_year: str
    dob: Optional[str] = None # Full Date of Birth String (YYYY-MM-DD)
    avatar_url: Optional[str] = None
    father_id: Optional[int] = None
    mother_id: Optional[int] = None
    spouses: List[int] = [] # IDs of spouses for visual grouping (optional)

class TreeEdge(BaseModel):
    from_id: int
    to_id: int
    type: str # 'FATHER_OF', 'MOTHER_OF', 'SPOUSE'

class TreeResponse(BaseModel):
    nodes: List[TreeNode]
    edges: List[TreeEdge]


# --- Family Schemas ---
class FamilyRead(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    origin_location: Optional[str] = None
    join_code: Optional[str] = None
    
    class Config:
        from_attributes = True

class FamilyCreate(BaseModel):
    name: str
    description: Optional[str] = None
    origin_location: Optional[str] = None

class FamilyUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    origin_location: Optional[str] = None

class JoinFamilyRequest(BaseModel):
    join_code: str

class UpdateMemberRoleRequest(BaseModel):
    role: str # 'editor' or 'member'


# --- Chat Schemas ---
class MessageCreate(BaseModel):
    content: str
    message_type: Optional[str] = "text"

class MessageRead(BaseModel):
    id: int
    family_id: int
    sender_id: int
    content: str
    created_at: str # Serialized datetime
    message_type: str
    
    # Optional: include sender info if needed for UI (name, avatar)
    sender_name: Optional[str] = None
    sender_avatar: Optional[str] = None

    class Config:
        from_attributes = True
