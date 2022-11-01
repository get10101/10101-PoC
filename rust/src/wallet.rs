use crate::logger::log;
use crate::seed::Bip39Seed;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::KeychainKind;
use bdk::SyncOptions;
use state::Storage;
use std::sync::Mutex;

pub const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
pub const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";

/// Wallet has to be managed by Rust as generics are not support by frb
static WALLET: Storage<Mutex<Wallet>> = Storage::new();

pub enum Network {
    Mainnet,
    Testnet,
    Regtest,
}

pub struct Wallet {
    blockchain: ElectrumBlockchain,
    wallet: bdk::Wallet<MemoryDatabase>,
    seed: Bip39Seed,
}

impl From<Network> for bitcoin::Network {
    fn from(network: Network) -> Self {
        match network {
            Network::Mainnet => bitcoin::Network::Bitcoin,
            Network::Testnet => bitcoin::Network::Testnet,
            Network::Regtest => bitcoin::Network::Regtest,
        }
    }
}

impl Wallet {
    pub fn new(network: Network) -> Result<Wallet> {
        let electrum_url = match network {
            Network::Mainnet => MAINNET_ELECTRUM,
            Network::Testnet => TESTNET_ELECTRUM,
            _ => bail!("Only public networks are supported"),
        };

        let seed = Bip39Seed::new()?;
        let ext_priv_key = seed.derive_extended_priv_key(network.into())?;

        let client = Client::new(electrum_url)?;
        let blockchain = ElectrumBlockchain::from(client);

        let wallet = bdk::Wallet::new(
            bdk::template::Bip84(ext_priv_key, KeychainKind::External),
            Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
            ext_priv_key.network,
            MemoryDatabase::new(),
        )?;

        Ok(Wallet {
            blockchain,
            wallet,
            seed,
        })
    }

    pub fn sync(&self) -> Result<bdk::Balance> {
        self.wallet.sync(&self.blockchain, SyncOptions::default())?;

        let balance = self.wallet.get_balance()?;
        log(&format!("Wallet balance: {} SAT", &balance));
        Ok(balance)
    }
}

/// Boilerplate wrappers for using Wallet with static functions in the library

pub fn init_wallet(network: Network) -> Result<()> {
    WALLET.set(Mutex::new(Wallet::new(network)?));
    Ok(())
}

pub fn get_balance() -> Result<bdk::Balance> {
    log("Wallet sync called");
    WALLET
        .try_get()
        .context("Wallet uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire wallet lock"))?
        .sync()
}

pub fn get_seed_phrase() -> Result<Vec<String>> {
    let wallet = WALLET
        .try_get()
        .context("Wallet uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire wallet lock"))?;

    Ok(wallet.seed.get_seed_phrase())
}

#[cfg(test)]
mod tests {
    use crate::wallet;

    use super::Network;

    #[test]
    fn wallet_support_for_different_bitcoin_networks() {
        wallet::init_wallet(Network::Mainnet).expect("wallet to be initialized");
        wallet::init_wallet(Network::Testnet).expect("wallet to be initialized");
        wallet::init_wallet(Network::Regtest).expect_err("wallet should not succeed to initialize");
    }
}
