CREATE TABLE IF NOT EXISTS cfd_state (
    id INTEGER PRIMARY KEY,
    state TEXT NOT NULL
);
INSERT INTO
    cfd_state (id, state)
VALUES
    (1, "Open");
INSERT INTO
    cfd_state (id, state)
VALUES
    (2, "Closed");
INSERT INTO
    cfd_state (id, state)
VALUES
    (3, "Failed");
CREATE TABLE IF NOT EXISTS cfd (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    custom_output_id TEXT UNIQUE NOT NULL,
    contract_symbol TEXT NOT NULL,
    position TEXT NOT NULL,
    leverage INTEGER NOT NULL,
    updated INTEGER NOT NULL,
    created INTEGER NOT NULL,
    state_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    expiry INTEGER NOT NULL,
    open_price REAL NOT NULL,
    liquidation_price REAL NOT NULL,
    FOREIGN KEY(state_id) REFERENCES cfd_state(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS dlc_id ON cfd(custom_output_id);
