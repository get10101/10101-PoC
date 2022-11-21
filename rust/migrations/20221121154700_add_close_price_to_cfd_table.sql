-- Add migration script here
ALTER TABLE
    cfd
ADD
    COLUMN close_price REAL;
