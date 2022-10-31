use crate::wallet;
use anyhow::Result;

pub fn init_wallet() -> Result<()> {
    wallet::init_wallet("testnet")
}
