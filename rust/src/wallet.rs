use crate::seed::Bip39Seed;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::wallet::AddressIndex;
use bdk::KeychainKind;
use bdk::SyncOptions;
use state::Storage;
use std::path::Path;
use std::sync::Mutex;
use std::sync::MutexGuard;

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
    pub fn new(network: Network, data_dir: &Path) -> Result<Wallet> {
        let electrum_url = match network {
            Network::Mainnet => MAINNET_ELECTRUM,
            Network::Testnet => TESTNET_ELECTRUM,
            _ => bail!("Only public networks are supported"),
        };

        let network: bitcoin::Network = network.into();
        let data_dir = data_dir.join(&network.to_string());
        if !data_dir.exists() {
            std::fs::create_dir(&data_dir)
                .context(format!("Could not create data dir for {network}"))?;
        }
        let seed_path = data_dir.join("seed");
        let seed = Bip39Seed::initialize(&seed_path)?;
        let ext_priv_key = seed.derive_extended_priv_key(network)?;

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
        tracing::debug!(%balance, "Wallet balance");
        Ok(balance)
    }

    pub fn get_address(&self) -> Result<bitcoin::Address> {
        let address = self.wallet.get_address(AddressIndex::LastUnused)?;
        tracing::debug!(%address, "Current wallet address");
        Ok(address.address)
    }
}

fn get_wallet() -> Result<MutexGuard<'static, Wallet>> {
    WALLET
        .try_get()
        .context("Wallet uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire wallet lock"))
}

/// Boilerplate wrappers for using Wallet with static functions in the library

pub fn init_wallet(network: Network, data_dir: &Path) -> Result<()> {
    tracing::debug!(?data_dir, "Wallet will be stored on disk");
    WALLET.set(Mutex::new(Wallet::new(network, data_dir)?));
    Ok(())
}

pub fn get_balance() -> Result<bdk::Balance> {
    tracing::debug!("Wallet sync called");
    get_wallet()?.sync()
}

pub fn get_address() -> Result<bitcoin::Address> {
    get_wallet()?.get_address()
}

pub fn get_seed_phrase() -> Result<Vec<String>> {
    let seed_phrase = get_wallet()?.seed.get_seed_phrase();
    Ok(seed_phrase)
}

#[cfg(test)]
mod tests {

    use std::env::temp_dir;

    use crate::wallet;

    use super::Network;

    #[test]
    fn wallet_support_for_different_bitcoin_networks() {
        wallet::init_wallet(Network::Mainnet, &temp_dir()).expect("wallet to be initialized");
        wallet::init_wallet(Network::Testnet, &temp_dir()).expect("wallet to be initialized");
        wallet::init_wallet(Network::Regtest, &temp_dir())
            .expect_err("wallet should not succeed to initialize");
    }
}
