-- ================================================
-- Family Tree Database Schema
-- ================================================
-- Script tạo toàn bộ cấu trúc database cho hệ thống gia phả
-- Date: 2026-02-10
-- ================================================

-- Tạo database (nếu chưa có)
CREATE DATABASE IF NOT EXISTS family_tree_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE family_tree_db;

-- ================================================
-- 1. TABLE: users
-- Quản lý tài khoản người dùng hệ thống
-- ================================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    gender ENUM('male', 'female', 'other'),
    date_of_birth DATE,
    place_of_birth VARCHAR(255),
    email VARCHAR(255) NOT NULL UNIQUE,
    cccd VARCHAR(12) UNIQUE COMMENT 'Căn cước công dân',
    role ENUM('admin', 'editor', 'member') NOT NULL DEFAULT 'member',
    
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_cccd (cccd)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Bảng quản lý người dùng hệ thống';


-- ================================================
-- 2. TABLE: families
-- Quản lý các gia phả
-- ================================================
CREATE TABLE IF NOT EXISTS families (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    origin_location VARCHAR(255) COMMENT 'Nguyên quán',
    join_code VARCHAR(10) UNIQUE COMMENT 'Mã tham gia gia phả',
    owner_id INT COMMENT 'Người tạo gia phả',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_join_code (join_code),
    INDEX idx_owner (owner_id),
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Bảng quản lý gia phả';


-- ================================================
-- 3. TABLE: persons
-- Quản lý thành viên trong gia phả
-- ================================================
CREATE TABLE IF NOT EXISTS persons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    family_id INT,
    user_id INT COMMENT 'Liên kết với tài khoản User (nếu có)',
    cccd VARCHAR(12) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    gender ENUM('male', 'female', 'other') NOT NULL DEFAULT 'male',
    role ENUM('admin', 'editor', 'member') DEFAULT 'member' COMMENT 'Quyền trong gia phả',
    date_of_birth DATE,
    date_of_death DATE,
    place_of_birth VARCHAR(255),
    avatar_url VARCHAR(255),
    father_id INT COMMENT 'ID của cha',
    mother_id INT COMMENT 'ID của mẹ',
    biography TEXT COMMENT 'Tiểu sử',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_family (family_id),
    INDEX idx_user (user_id),
    INDEX idx_cccd (cccd),
    INDEX idx_father (father_id),
    INDEX idx_mother (mother_id),
    
    FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (father_id) REFERENCES persons(id) ON DELETE SET NULL,
    FOREIGN KEY (mother_id) REFERENCES persons(id) ON DELETE SET NULL,
    
    CONSTRAINT uq_family_member_cccd UNIQUE (family_id, cccd)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Bảng quản lý thành viên gia phả';


-- ================================================
-- 4. TABLE: relationships
-- Quản lý mối quan hệ giữa các thành viên
-- ================================================
CREATE TABLE IF NOT EXISTS relationships (
    id INT AUTO_INCREMENT PRIMARY KEY,
    person1_id INT NOT NULL COMMENT 'ID người thứ nhất',
    person2_id INT NOT NULL COMMENT 'ID người thứ hai',
    type VARCHAR(50) NOT NULL COMMENT 'Loại quan hệ: bố, mẹ, vợ, chồng, anh, chị, em, etc.',
    
    INDEX idx_person1 (person1_id),
    INDEX idx_person2 (person2_id),
    INDEX idx_type (type),
    INDEX idx_pair (person1_id, person2_id),
    
    FOREIGN KEY (person1_id) REFERENCES persons(id) ON DELETE CASCADE,
    FOREIGN KEY (person2_id) REFERENCES persons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Bảng quản lý mối quan hệ giữa các thành viên';


-- ================================================
-- 5. TABLE: messages
-- Quản lý tin nhắn chat của gia phả
-- ================================================
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    family_id INT NOT NULL,
    sender_id INT NOT NULL COMMENT 'ID người gửi (User)',
    content TEXT NOT NULL COMMENT 'Nội dung tin nhắn',
    message_type VARCHAR(20) DEFAULT 'text' COMMENT 'Loại: text, image, file',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_family (family_id),
    INDEX idx_sender (sender_id),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Bảng quản lý tin nhắn chat';


-- ================================================
-- Tạo thư mục uploads (placeholder table)
-- ================================================
-- NOTE: Thư mục uploads được quản lý bởi backend,
-- không cần table riêng trong database


-- ================================================
-- Sample Data (Optional - Uncomment để insert dữ liệu mẫu)
-- ================================================

-- Insert admin user mẫu
-- INSERT INTO users (username, password_hash, email, role, first_name, last_name) 
-- VALUES ('admin', 'hashed_password_here', 'admin@familytree.com', 'admin', 'Admin', 'System');

-- Insert gia phả mẫu
-- INSERT INTO families (name, description, origin_location, join_code, owner_id) 
-- VALUES ('Họ Nguyễn', 'Gia phả họ Nguyễn tại Hà Nội', 'Hà Nội', 'NGUYEN01', 1);


-- ================================================
-- Verification Queries
-- ================================================

-- Kiểm tra các bảng đã được tạo
SHOW TABLES;

-- Xem cấu trúc các bảng
-- DESCRIBE users;
-- DESCRIBE families;
-- DESCRIBE persons;
-- DESCRIBE relationships;
-- DESCRIBE messages;


-- ================================================
-- Drop Tables (USE WITH CAUTION! - Xóa toàn bộ dữ liệu)
-- ================================================

-- Uncomment để xóa tất cả các bảng (theo thứ tự dependency)
-- SET FOREIGN_KEY_CHECKS = 0;
-- DROP TABLE IF EXISTS messages;
-- DROP TABLE IF EXISTS relationships;
-- DROP TABLE IF EXISTS persons;
-- DROP TABLE IF EXISTS families;
-- DROP TABLE IF EXISTS users;
-- SET FOREIGN_KEY_CHECKS = 1;


-- ================================================
-- END OF SCRIPT
-- ================================================
