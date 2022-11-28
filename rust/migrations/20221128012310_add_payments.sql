-- Add lightning payments table
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_hash TEXT UNIQUE NOT NULL,
    preimage TEXT,
    secret TEXT,
    htlc_status TEXT NOT NULL,
    amount_msat INTEGER,
    created INTEGER NOT NULL,
    updated INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS payment_hash ON payments (payment_hash);
