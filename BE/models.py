from sqlalchemy import (
    Column, Integer, String, Date, ForeignKey, Text, Enum, TIMESTAMP, UniqueConstraint
)
from sqlalchemy.orm import relationship
from db.mysql_connection import Base
import enum

# Enum cho role
class UserRole(str, enum.Enum):
    admin = "admin"
    editor = "editor"
    member = "member"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    gender = Column(Enum('male', 'female', 'other'), nullable=True)
    date_of_birth = Column(Date, nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    email = Column(String(255), unique=True, nullable=False)
    cccd = Column(String(12), unique=True, nullable=True) # Added CCCD
    role = Column(Enum(UserRole), nullable=False)

class Family(Base):
    __tablename__ = "families"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    origin_location = Column(String(255), nullable=True)
    join_code = Column(String(10), unique=True, nullable=True) # Mã tham gia gia phả
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True) # Người tạo/Sở hữu gia phả
    created_at = Column(TIMESTAMP, nullable=True)

    members = relationship("Person", back_populates="family")


class Person(Base):
    __tablename__ = "persons"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True) # Liên kết trực tiếp với User hệ thống
    cccd = Column(String(12), unique=True, nullable=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=True)
    gender = Column(Enum('male', 'female', 'other'), nullable=False)
    role = Column(Enum('admin', 'editor', 'member'), default='member') # Phân quyền trong gia phả
    date_of_birth = Column(Date, nullable=True)
    date_of_death = Column(Date, nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    father_id = Column(Integer, ForeignKey("persons.id"), nullable=True)
    mother_id = Column(Integer, ForeignKey("persons.id"), nullable=True)
    biography = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, nullable=True)

    # Quan hệ ORM
    family = relationship("Family", back_populates="members")
    father = relationship("Person", remote_side=[id], foreign_keys=[father_id], post_update=True)
    mother = relationship("Person", remote_side=[id], foreign_keys=[mother_id], post_update=True)

    __table_args__ = (
        UniqueConstraint('family_id', 'cccd', name='uq_family_member_cccd'),
    )


class Relationship(Base):
    __tablename__ = "relationships"

    id = Column(Integer, primary_key=True, index=True)
    person1_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    person2_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    type = Column(String(50), nullable=False) # "bố", "mẹ", "vợ", "chồng", "anh ruột", "chị ruột", "em ruột"

    # ORM
    person1 = relationship("Person", foreign_keys=[person1_id])
    person2 = relationship("Person", foreign_keys=[person2_id])


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(TIMESTAMP, nullable=False)
    message_type = Column(String(20), default="text") # text, image, file

    # ORM
    family = relationship("Family")
    sender = relationship("User")
