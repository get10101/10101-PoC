use crate::lightning;
use crate::lightning::LightningSystem;
use crate::lightning::PeerInfo;
use crate::seed::Bip39Seed;
use anyhow::anyhow;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::blockchain::{ElectrumBlockchain, GetHeight};
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::wallet::AddressIndex;
use bdk::KeychainKind;
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
        let result = blockchain.get_height()?;

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

    pub fn sync(&self) -> Result<bdk::Balance> {
        self.lightning
            .wallet
            .sync(self.lightning.confirmables())
            .map_err(|_| anyhow!("Could lot sync bdk-ldk wallet"))?;
        self.get_bdk_balance()
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
    pub async fn run_ldk(&self, listening_port: u16) -> Result<()> {
        lightning::run_ldk(&self.lightning, listening_port).await
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

pub async fn run_ldk(listening_port: u16) -> Result<()> {
    let wallet = { (*get_wallet()?).clone() };
    wallet.run_ldk(listening_port).await
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
