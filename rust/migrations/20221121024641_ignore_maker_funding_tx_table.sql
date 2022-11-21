-- Store the maker's funding transaction id so we can ignore it when creating the bitcoin tx history
CREATE TABLE IF NOT EXISTS ignore_txid (
    id INTEGER PRIMARY KEY,
    txid TEXT NOT NULL
);
