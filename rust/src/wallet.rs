use crate::lightning;
use crate::lightning::LightningSystem;
use crate::lightning::PeerInfo;
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
use lightning_background_processor::BackgroundProcessor;
use state::Storage;
use std::path::Path;
use std::sync::Mutex;
use std::sync::MutexGuard;

pub const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
pub const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";
pub const REGTEST_ELECTRUM: &str = "tcp://localhost:50000";

/// Wallet has to be managed by Rust as generics are not support by frb
static WALLET: Storage<Mutex<Wallet>> = Storage::new();

pub enum Network {
    Mainnet,
    Testnet,
    Regtest,
}

#[derive(Clone)]
pub struct Wallet {
    seed: Bip39Seed,
    lightning: LightningSystem,
}

pub struct Balance {
    pub on_chain: u64,
    pub off_chain: u64,
}

impl Wallet {
    pub fn new(network: Network, data_dir: &Path) -> Result<Wallet> {
        let electrum_url = match network {
            Network::Mainnet => MAINNET_ELECTRUM,
            Network::Testnet => TESTNET_ELECTRUM,
            Network::Regtest => REGTEST_ELECTRUM,
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

        let bdk_wallet = bdk::Wallet::new(
            bdk::template::Bip84(ext_priv_key, KeychainKind::External),
            Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
            ext_priv_key.network,
            MemoryDatabase::new(),
        )?;

        let lightning_wallet = bdk_ldk::LightningWallet::new(Box::new(blockchain), bdk_wallet);

        // Lightning seed needs to be shorter
        let lightning_seed = &seed.seed()[0..32].try_into()?;

        let lightning = lightning::setup(lightning_wallet, network, &data_dir, lightning_seed)?;

        Ok(Wallet { lightning, seed })
    }

    pub fn sync(&self) -> Result<Balance> {
        self.lightning
            .wallet
            .sync(self.lightning.confirmables())
            .map_err(|_| anyhow!("Could lot sync bdk-ldk wallet"))?;

        let bdk_balance = self.get_bdk_balance()?;
        let ldk_balance = self.get_ldk_balance()?;
        Ok(Balance {
            // subtract the ldk balance from the bdk balance as this balance is locked in the
            // off chain wallet.
            on_chain: bdk_balance.confirmed,
            off_chain: ldk_balance,
        })
    }

    fn get_bdk_balance(&self) -> Result<bdk::Balance> {
        let balance = self
            .lightning
            .wallet
            .get_balance()
            .map_err(|_| anyhow!("Could not retrieve bdk wallet balance"))?;
        tracing::debug!(%balance, "Wallet balance");
        Ok(balance)
    }

    fn get_ldk_balance(&self) -> Result<u64> {
        let channels = self.lightning.channel_manager.list_channels();
        if channels.len() == 1 {
            return Ok(channels.first().expect("Opened channel").balance_msat / 1000);
        }
        tracing::warn!("Expected exactly 1 channel but found {}", channels.len());
        Ok(0)
    }

    pub fn get_address(&self) -> Result<bitcoin::Address> {
        let address = self
            .lightning
            .wallet
            .get_wallet()
            .get_address(AddressIndex::LastUnused)?;
        tracing::debug!(%address, "Current wallet address");
        Ok(address.address)
    }

    /// Run the lightning node
    pub async fn run_ldk(&self) -> Result<BackgroundProcessor> {
        lightning::run_ldk(&self.lightning).await
    }

    pub fn get_bitcoin_tx_history(&self) -> Result<Vec<bdk::TransactionDetails>> {
        let tx_history = self
            .lightning
            .wallet
            .get_wallet()
            .list_transactions(false)?;
        tracing::debug!(?tx_history, "Transaction history");
        Ok(tx_history)
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

pub async fn run_ldk() -> Result<BackgroundProcessor> {
    let wallet = { (*get_wallet()?).clone() };
    wallet.run_ldk().await
}

pub fn get_balance() -> Result<Balance> {
    tracing::debug!("Wallet sync called");
    get_wallet()?.sync()
}

pub fn get_address() -> Result<bitcoin::Address> {
    get_wallet()?.get_address()
}

pub fn get_bitcoin_tx_history() -> Result<Vec<bdk::TransactionDetails>> {
    get_wallet()?.get_bitcoin_tx_history()
}

pub fn get_seed_phrase() -> Result<Vec<String>> {
    let seed_phrase = get_wallet()?.seed.get_seed_phrase();
    Ok(seed_phrase)
}

pub async fn open_channel(peer_info: PeerInfo, channel_amount_sat: u64) -> Result<()> {
    let (peer_manager, channel_manager, data_dir) = {
        let lightning = &get_wallet()?.lightning;
        (
            lightning.peer_manager.clone(),
            lightning.channel_manager.clone(),
            lightning.data_dir.clone(),
        )
    };

    lightning::open_channel(
        peer_manager,
        channel_manager,
        peer_info,
        channel_amount_sat,
        data_dir.as_path(),
    )
    .await
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
