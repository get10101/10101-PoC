-- Add expiry timestamp to payment info
-- Needed to be able to mark a payment as failed
-- it can be null, we often do not know the expiry timestamp
ALTER TABLE
    payments
ADD
    COLUMN expiry INTEGER;
