use crate::lightning;
use crate::lightning::HTLCStatus;
use crate::lightning::LightningSystem;
use crate::lightning::PeerInfo;
use crate::seed::Bip39Seed;
use ::lightning::chain::chaininterface::ConfirmationTarget;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::Address;
use bdk::bitcoin::Amount;
use bdk::bitcoin::Script;
use bdk::bitcoin::Txid;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::wallet::AddressIndex;
use bdk::FeeRate;
use bdk::KeychainKind;
use bdk::SignOptions;
use bdk_ldk::ScriptStatus;
use lightning_background_processor::BackgroundProcessor;
use lightning_invoice::Invoice;
use reqwest::StatusCode;
use rust_decimal::prelude::FromPrimitive;
use serde::Deserialize;
use serde::Serialize;
use state::Storage;
use std::fmt;
use std::fmt::Display;
use std::fmt::Formatter;
use std::net::SocketAddr;
use std::path::Path;
use std::str::FromStr;
use std::sync::Mutex;
use std::sync::MutexGuard;
use std::time::Duration;
use tokio::task::JoinHandle;

pub const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
pub const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";
pub const REGTEST_ELECTRUM: &str = "tcp://localhost:50000";

/// Wallet has to be managed by Rust as generics are not support by frb
static WALLET: Storage<Mutex<Wallet>> = Storage::new();

pub static MAKER_IP: &str = "127.0.0.1";
pub static MAKER_PORT_LIGHTNING: u64 = 9045;
pub static MAKER_PORT_HTTP: u64 = 8000;
// Maker PK is derived from our checked in regtest maker seed
pub static MAKER_PK: &str = "02cb6517193c466de0688b8b0386dbfb39d96c3844525c1315d44bd8e108c08bc1";
pub static MAKER_ENDPOINT: &str = "http://127.0.0.1:8000";

pub static TCP_TIMEOUT: Duration = Duration::from_secs(10);

pub fn maker_peer_info() -> PeerInfo {
    PeerInfo {
        pubkey: MAKER_PK.parse().expect("Hard-coded PK to be valid"),
        peer_addr: format!("{MAKER_IP}:{MAKER_PORT_LIGHTNING}")
            .parse()
            .expect("Hard-coded PK to be valid"),
    }
}

#[derive(Clone)]
pub enum Network {
    Mainnet,
    Testnet,
    Regtest,
}

impl Display for Network {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            Network::Mainnet => "mainnet",
            Network::Testnet => "testnet",
            Network::Regtest => "regtest",
        }
        .fmt(f)
    }
}

#[derive(Clone)]
pub struct Wallet {
    seed: Bip39Seed,
    pub lightning: LightningSystem,
}

#[derive(Debug, Clone, Serialize)]
pub struct Balance {
    pub on_chain: OnChain,
    pub off_chain: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct OnChain {
    /// Unconfirmed UTXOs generated by a wallet tx
    pub trusted_pending: u64,
    /// Unconfirmed UTXOs received from an external wallet
    pub untrusted_pending: u64,
    /// Confirmed and immediately spendable balance
    pub confirmed: u64,
}

impl Wallet {
    pub fn new(network: Network, electrum_url: &str, data_dir: &Path) -> Result<Wallet> {
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
            on_chain: OnChain {
                trusted_pending: bdk_balance.trusted_pending,
                untrusted_pending: bdk_balance.untrusted_pending,
                confirmed: bdk_balance.confirmed,
            },
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
            .get_wallet()?
            .get_address(AddressIndex::LastUnused)?;
        tracing::debug!(%address, "Current wallet address");
        Ok(address.address)
    }

    /// Run the lightning node
    pub async fn run_ldk(&self) -> Result<BackgroundProcessor> {
        lightning::run_ldk(&self.lightning).await
    }

    /// Run the lightning node
    pub async fn run_ldk_server(
        &self,
        address: SocketAddr,
    ) -> Result<(JoinHandle<()>, BackgroundProcessor)> {
        lightning::run_ldk_server(&self.lightning, address).await
    }

    pub fn get_bitcoin_tx_history(&self) -> Result<Vec<bdk::TransactionDetails>> {
        let tx_history = self
            .lightning
            .wallet
            .get_wallet()?
            .list_transactions(false)?;
        tracing::debug!(?tx_history, "Transaction history");
        Ok(tx_history)
    }

    pub fn get_node_id(&self) -> PublicKey {
        self.lightning.channel_manager.get_our_node_id()
    }

    pub fn get_script_status(&self, script: Script, txid: Txid) -> Result<ScriptStatus> {
        let script_status = self
            .lightning
            .wallet
            .get_tx_status_for_script(script, txid)
            .map_err(|_| anyhow!("Could not get tx status for script"))?;
        Ok(script_status)
    }

    pub fn send_to_address(&self, send_to: Address, amount: u64) -> Result<Txid> {
        self.sync()?;

        let wallet = self.lightning.wallet.get_wallet()?;

        let estimated_fee_rate = self
            .lightning
            .wallet
            .estimate_fee(ConfirmationTarget::Normal)
            .map_err(|_| anyhow!("Failed to estimate fee"))?;

        let (mut psbt, _) = {
            let mut builder = wallet.build_tx();
            builder
                .add_recipient(send_to.script_pubkey(), amount)
                .enable_rbf()
                .fee_rate(FeeRate::from_sat_per_vb(
                    f32::from_u32(estimated_fee_rate).unwrap_or(1.0),
                ));
            builder.finish()?
        };

        if !wallet.sign(&mut psbt, SignOptions::default())? {
            bail!("Failed to sign psbt");
        }

        let tx = psbt.extract_tx();

        self.lightning.wallet.broadcast(&tx)?;

        Ok(tx.txid())
    }

    pub fn send_lightning_payment(&self, invoice: &Invoice) -> Result<()> {
        lightning::send_payment(invoice, self.lightning.outbound_payments.clone())?;
        Ok(())
    }

    pub fn get_invoice(&self, amount_msat: u64, expiry_secs: u32) -> Result<()> {
        lightning::get_invoice(
            amount_msat,
            self.lightning.inbound_payments.clone(),
            self.lightning.channel_manager.clone(),
            self.lightning.keys_manager.clone(),
            self.lightning.network,
            expiry_secs,
            self.lightning.logger.clone(),
        )
    }
}

pub fn get_wallet() -> Result<MutexGuard<'static, Wallet>> {
    WALLET
        .try_get()
        .context("Wallet uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire wallet lock"))
}

/// Boilerplate wrappers for using Wallet with static functions in the library

pub fn init_wallet(network: Network, electrum_url: &str, data_dir: &Path) -> Result<()> {
    tracing::debug!(?data_dir, "Wallet will be stored on disk");
    WALLET.set(Mutex::new(Wallet::new(network, electrum_url, data_dir)?));
    Ok(())
}

pub async fn run_ldk() -> Result<BackgroundProcessor> {
    let wallet = { (*get_wallet()?).clone() };
    wallet.run_ldk().await
}

pub async fn run_ldk_server(address: SocketAddr) -> Result<(JoinHandle<()>, BackgroundProcessor)> {
    let wallet = { (*get_wallet()?).clone() };
    wallet.run_ldk_server(address).await
}

pub fn node_id() -> Result<PublicKey> {
    let node_id = get_wallet()?.get_node_id();
    Ok(node_id)
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

pub fn get_lightning_history() -> Result<Vec<LightningTransaction>> {
    let (outbound, inbound) = {
        let lightning = &get_wallet()?.lightning;
        let x = (
            lightning.outbound_payments.lock().unwrap().clone(),
            lightning.inbound_payments.lock().unwrap().clone(),
        );
        x
    };
    let mut outbound = outbound
        .iter()
        .map(|(_, payment_info)| LightningTransaction {
            tx_type: LightningTransactionType::Payment,
            flow: Flow::Outbound,
            sats: Amount::from(payment_info.amt_msat.clone()).to_sat(),
            status: payment_info.status.clone().into(),
            timestamp: payment_info.timestamp,
        })
        .collect();

    let mut inbound = inbound
        .iter()
        .map(|(_, payment_info)| LightningTransaction {
            tx_type: LightningTransactionType::Payment,
            flow: Flow::Inbound,
            sats: Amount::from(payment_info.amt_msat.clone()).to_sat(),
            status: payment_info.status.clone().into(),
            timestamp: payment_info.timestamp,
        })
        .collect::<Vec<_>>();

    inbound.append(&mut outbound);
    Ok(inbound)
}

pub fn get_seed_phrase() -> Result<Vec<String>> {
    let seed_phrase = get_wallet()?.seed.get_seed_phrase();
    Ok(seed_phrase)
}

pub fn send_lightning_payment(invoice: &str) -> Result<()> {
    let invoice = Invoice::from_str(invoice).context("Could not parse Invoice string")?;
    get_wallet()?.send_lightning_payment(&invoice)
}

#[derive(Serialize, Deserialize, Debug)]
pub struct OpenChannelRequest {
    /// The taker address where the maker should send the funds to
    pub address_to_fund: Address,

    /// The amount that the taker expects for funding
    ///
    /// This represents the amount of the maker.
    pub fund_amount: u64,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct OpenChannelResponse {
    pub funding_txid: Txid,
}

pub async fn open_channel(peer_info: PeerInfo, taker_amount: u64) -> Result<()> {
    let maker_amount = taker_amount * 2;
    let channel_capacity = taker_amount + maker_amount;

    let address_to_fund = get_address()?;

    let client = reqwest::Client::builder().timeout(TCP_TIMEOUT).build()?;

    let body = OpenChannelRequest {
        address_to_fund: address_to_fund.clone(),
        fund_amount: maker_amount,
    };

    let maker_api = format!("http://{MAKER_IP}:{MAKER_PORT_HTTP}/api/channel/open");

    tracing::info!("Sending request to open channel to maker at: {maker_api}");

    let response = client.post(maker_api).json(&body).send().await?;

    if response.status() == StatusCode::INTERNAL_SERVER_ERROR
        || response.status() == StatusCode::BAD_REQUEST
    {
        let text = response.text().await?;
        bail!("open channel request failed with response: {text}")
    }

    let response: OpenChannelResponse = response.json().await?;

    // TODO: Add txid to "txid-to-be-ignored" when loading the bitcoin tx-history list and balance
    //  This will require filtering the tx history and remove entries for the txid as well as
    // subtracting the amount from the balance.

    // We cannot wait indefinitely so we specify how long we wait for the maker funds to arrive in
    // mempool
    let secs_until_we_consider_maker_funding_failed = 600;

    let mut processing_sec_counter = 0;
    let sleep_secs = 5;
    while get_wallet()?.get_script_status(address_to_fund.script_pubkey(), response.funding_txid)?
        == ScriptStatus::Unseen
    {
        processing_sec_counter += sleep_secs;
        if processing_sec_counter >= secs_until_we_consider_maker_funding_failed {
            bail!("The maker screwed up, the funds did not arrive within {secs_until_we_consider_maker_funding_failed} secs so we cannot open channel");
        }

        tokio::time::sleep(Duration::from_secs(sleep_secs)).await;
    }

    // Open Channel
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
        channel_capacity,
        data_dir.as_path(),
        Some(maker_amount),
    )
    .await
}

pub async fn force_close_channel(remote_node_id: PublicKey) -> Result<()> {
    let channel_manager = {
        let lightning = &get_wallet()?.lightning;

        lightning.channel_manager.clone()
    };

    lightning::force_close_channel(channel_manager, remote_node_id).await?;

    Ok(())
}

pub fn send_to_address(address: Address, amount: u64) -> Result<Txid> {
    get_wallet()?.send_to_address(address, amount)
}

pub fn get_node_id() -> Result<PublicKey> {
    let guard = get_wallet()?;
    let node_id = guard.get_node_id();

    Ok(node_id)
}

pub fn get_invoice(amount_msat: u64, expiry_secs: u32) -> Result<()> {
    get_wallet()?.get_invoice(amount_msat, expiry_secs)
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

pub enum LightningTransactionType {
    Payment,
    Cfd,
}

pub struct LightningTransaction {
    pub tx_type: LightningTransactionType,
    pub flow: Flow,
    pub sats: u64,
    pub status: TransactionStatus,
    pub timestamp: u64,
}

pub enum Flow {
    Inbound,
    Outbound,
}

// TODO: Remove this? Seems to be exactly the same as HTLCStatus
pub enum TransactionStatus {
    Failed,
    Succeeded,
    Pending,
}

impl From<HTLCStatus> for TransactionStatus {
    fn from(s: HTLCStatus) -> Self {
        match s {
            HTLCStatus::Succeeded => TransactionStatus::Succeeded,
            HTLCStatus::Failed => TransactionStatus::Failed,
            HTLCStatus::Pending => TransactionStatus::Pending,
        }
    }
}
