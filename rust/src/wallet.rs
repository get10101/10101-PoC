use crate::seed::Bip39Seed;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin::Network;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::KeychainKind;
use bdk::SyncOptions;
use state::Storage;
use std::str::FromStr;
use std::sync::Mutex;

pub const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
pub const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";

/// Wallet has to be managed by Rust as generics are not support by frb
static WALLET: Storage<Mutex<Wallet>> = Storage::new();

pub struct Wallet {
    blockchain: ElectrumBlockchain,
    wallet: bdk::Wallet<MemoryDatabase>,
}

impl Wallet {
    pub fn new(network: &str) -> Result<Wallet> {
        let network = Network::from_str(network)?;

        let electrum_url = match network {
            Network::Bitcoin => MAINNET_ELECTRUM,
            Network::Testnet => TESTNET_ELECTRUM,
            _ => bail!("Only public networks are supported"),
        };

        let seed = Bip39Seed::new()?;
        let ext_priv_key = seed.derive_extended_priv_key(network)?;

        let client = Client::new(electrum_url)?;
        let blockchain = ElectrumBlockchain::from(client);

        let wallet = bdk::Wallet::new(
            bdk::template::Bip84(ext_priv_key, KeychainKind::External),
            Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
            ext_priv_key.network,
            MemoryDatabase::new(),
        )?;

        Ok(Wallet { blockchain, wallet })
    }

    pub fn sync(&self) -> Result<bdk::Balance> {
        self.wallet.sync(&self.blockchain, SyncOptions::default())?;

        let balance = self.wallet.get_balance()?;
        println!("Wallet balance: {} SAT", &balance);
        Ok(balance)
    }
}

/// Boilerplate wrappers for using Wallet with static functions in the library

pub fn init_wallet(network: &str) -> Result<()> {
    WALLET.set(Mutex::new(Wallet::new(network)?));
    Ok(())
}

pub fn get_balance() -> Result<bdk::Balance> {
    println!("Wallet sync called");
    WALLET
        .try_get()
        .context("Wallet uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire wallet lock"))?
        .sync()
}

#[cfg(test)]
mod tests {
    use crate::wallet;

    #[test]
    fn init_wallet_success() {
        wallet::init_wallet("bitcoin").expect("wallet to be initialized");
        wallet::init_wallet("testnet").expect("wallet to be initialized");
    }

    #[test]
    fn init_wallet_fail() {
        wallet::init_wallet("regtest").expect_err("wallet should not succeed to initialize");
        wallet::init_wallet("blabla").expect_err("wallet should not succeed to initialize");
    }
}
