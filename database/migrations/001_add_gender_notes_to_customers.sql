-- Migration: Add gender and notes to customers
-- Run this ONLY if your DB was created before these columns were added.
-- If you get "Duplicate column name" error, that column already exists - skip it.
-- Run via: mysql -u USER -p DB_NAME < 001_add_gender_notes_to_customers.sql

ALTER TABLE customers ADD COLUMN gender VARCHAR(20) NULL AFTER phone_number;
ALTER TABLE customers ADD COLUMN notes TEXT NULL AFTER gender;
