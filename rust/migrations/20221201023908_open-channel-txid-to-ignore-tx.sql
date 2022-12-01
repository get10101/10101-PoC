-- Add migration script here
-- Add txid of opening the channel where the maker_amount has to be subtracted on the taker side
-- This txid is updated once we can extract it from the channel (i.e. once it's available) and then saved and loaded from the db on consecutive calls.
ALTER TABLE
    ignore_txid
ADD
    COLUMN open_channel_txid TEXT;
