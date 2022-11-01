use crate::wallet;
use crate::wallet::Network;
use anyhow::Result;

pub struct Balance {
    pub confirmed: u64,
}

impl Balance {
    pub fn new(confirmed: u64) -> Balance {
        Balance { confirmed }
    }
}

pub fn init_wallet(network: Network) -> Result<()> {
    wallet::init_wallet(network)
}

pub fn get_balance() -> anyhow::Result<Balance> {
    Ok(Balance::new(wallet::get_balance()?.confirmed))
}
