use crate::calc;
use crate::cfd;
use crate::cfd::models::Cfd;
use crate::cfd::models::Order;
use crate::cfd::models::Position;
use crate::config;
use crate::connection;
use crate::db;
use crate::faucet;
use crate::logger;
use crate::offer;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::Balance;
use crate::wallet::LightningTransaction;
use anyhow::anyhow;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use flutter_rust_bridge::SyncReturn;
use lightning_invoice::Invoice;
use lightning_invoice::InvoiceDescription;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use std::ops::Add;
use std::path::Path;
use std::str::FromStr;
use std::time::SystemTime;
use time::Duration;
pub use time::OffsetDateTime;
use tokio::try_join;

pub struct Address {
    pub address: String,
}

#[derive(Clone)]
pub struct BitcoinTxHistoryItem {
    pub sent: u64,
    pub received: u64,
    pub txid: String,
    pub fee: u64,
    pub is_confirmed: bool,
    /// Timestamp since epoch
    ///
    /// Confirmation timestamp as prt blocktime if confirmed, otherwise current time since epoch is
    /// returned.
    pub timestamp: u64,
}

impl Address {
    pub fn new(address: String) -> Address {
        Address { address }
    }
}

#[derive(Clone)]
pub enum ChannelState {
    Unavailable,
    Establishing,
    Disconnected,
    Available,
}

fn get_channel_state() -> ChannelState {
    match wallet::get_first_channel_details() {
        Some(channel_details) => {
            if channel_details.is_usable {
                ChannelState::Available
            } else if channel_details.is_channel_ready {
                // an unusable, but ready channel indicates that the maker might be
                // disconnected.
                ChannelState::Disconnected
            } else {
                // if the channel is not usable and not ready - we are currently establishing a
                // channel with the maker.
                ChannelState::Establishing
            }
        }
        None => ChannelState::Unavailable,
    }
}

pub struct LightningInvoice {
    pub description: String,
    pub amount_sats: f64,
    pub timestamp: u64,
    pub payee: String,
    pub expiry: u64,
}

pub fn decode_invoice(invoice: String) -> Result<LightningInvoice> {
    anyhow::ensure!(!invoice.is_empty(), "received empty invoice");
    let invoice = &Invoice::from_str(&invoice).context("Could not parse invoice string")?;
    let description = match invoice.description() {
        InvoiceDescription::Direct(direct) => direct.to_string(),
        InvoiceDescription::Hash(_) => "".to_string(),
    };
    // can't use as_millis as the frb does not support u128
    let timestamp = invoice
        .timestamp()
        .duration_since(SystemTime::UNIX_EPOCH)?
        .as_secs();

    let expiry = SystemTime::now()
        .add(Duration::seconds(invoice.expiry_time().as_secs() as i64))
        .duration_since(SystemTime::UNIX_EPOCH)?
        .as_secs();

    Ok(LightningInvoice {
        description,
        timestamp,
        expiry,
        amount_sats: (invoice.amount_milli_satoshis().expect("amount") as f64 / 1000.0),
        payee: invoice.payee_pub_key().expect("payee pubkey").to_string(),
    })
}

#[derive(Clone)]
pub enum Event {
    Init(String),
    Ready,
    Offer(Option<Offer>),
    WalletInfo(Option<WalletInfo>),
    ChannelState(ChannelState),
}

#[derive(Clone)]
pub struct WalletInfo {
    pub balance: Balance,
    pub bitcoin_history: Vec<BitcoinTxHistoryItem>,
    pub lightning_history: Vec<LightningTransaction>,
}

impl WalletInfo {
    async fn build_wallet_info() -> Result<WalletInfo> {
        let balance = wallet::get_balance()?;
        let bitcoin_history = WalletInfo::get_bitcoin_tx_history().await?;
        let lightning_history = wallet::get_lightning_history().await?;
        Ok(WalletInfo {
            balance,
            bitcoin_history,
            lightning_history,
        })
    }

    async fn get_bitcoin_tx_history() -> Result<Vec<BitcoinTxHistoryItem>> {
        let tx_history = wallet::get_bitcoin_tx_history()
            .await?
            .into_iter()
            .map(|tx| {
                let (is_confirmed, timestamp) = match tx.confirmation_time {
                    None => (false, OffsetDateTime::now_utc().unix_timestamp() as u64),
                    Some(blocktime) => (true, blocktime.timestamp),
                };

                BitcoinTxHistoryItem {
                    sent: tx.sent,
                    received: tx.received,
                    txid: tx.txid.to_string(),
                    fee: tx.fee.unwrap_or(0),
                    is_confirmed,
                    timestamp,
                }
            })
            .collect::<Vec<_>>();

        Ok(tx_history)
    }
}

#[tokio::main(flavor = "current_thread")]
pub async fn refresh_wallet_info() -> Result<WalletInfo> {
    wallet::sync()?;
    WalletInfo::build_wallet_info().await
}

#[tokio::main(flavor = "current_thread")]
pub async fn run(stream: StreamSink<Event>, app_dir: String) -> Result<()> {
    let network = config::network();
    anyhow::ensure!(!app_dir.is_empty(), "app_dir must not be empty");
    stream.add(Event::Init(format!("Initialising {network} wallet")));
    wallet::init_wallet(Path::new(app_dir.as_str()))?;

    stream.add(Event::Init("Initialising database".to_string()));
    db::init_db(
        &Path::new(app_dir.as_str())
            .join(network.to_string())
            .join("taker.sqlite"),
    )
    .await?;

    stream.add(Event::Init("Starting full ldk node".to_string()));
    let background_processor = wallet::run_ldk().await?;

    stream.add(Event::Init("Fetching an offer".to_string()));
    stream.add(Event::Offer(offer::get_offer().await.ok()));

    stream.add(Event::Init("Fetching your balance".to_string()));
    stream.add(Event::WalletInfo(
        WalletInfo::build_wallet_info().await.ok(),
    ));
    stream.add(Event::Init("Checking channel state".to_string()));
    stream.add(Event::ChannelState(get_channel_state()));

    stream.add(Event::Init("Ready".to_string()));
    stream.add(Event::Ready);

    // spawn a connection task keeping the connection with the maker alive.
    let peer_manager = wallet::get_peer_manager()?;
    let connection_handle = connection::spawn(peer_manager);

    // sync offers every 5 seconds
    let offer_handle = offer::spawn(stream.clone());

    // sync wallet every 60 seconds
    let wallet_sync_handle = tokio::spawn(async {
        loop {
            wallet::sync().unwrap_or_else(|e| tracing::error!(?e, "Failed to sync wallet"));
            tokio::time::sleep(std::time::Duration::from_secs(60)).await;
        }
    });

    // sync wallet info every 10 seconds
    let wallet_info_stream = stream.clone();
    let wallet_info_sync_handle = tokio::spawn(async move {
        loop {
            match WalletInfo::build_wallet_info().await {
                Ok(wallet_info) => {
                    let _ = wallet_info_stream.add(Event::WalletInfo(Some(wallet_info)));
                }
                Err(e) => tracing::error!(?e, "Failed to build wallet info"),
            }
            tokio::time::sleep(std::time::Duration::from_secs(10)).await;
        }
    });

    // sync channel state every 5 seconds
    let channel_state_stream = stream.clone();
    let channel_state_handle = tokio::spawn(async move {
        loop {
            channel_state_stream.add(Event::ChannelState(get_channel_state()));
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    });

    try_join!(
        connection_handle,
        offer_handle,
        wallet_sync_handle,
        wallet_info_sync_handle,
        channel_state_handle,
    )?;

    background_processor.join().map_err(|e| anyhow!(e))
}

pub fn get_balance() -> Result<Balance> {
    wallet::get_balance()
}

pub fn sync() -> Result<()> {
    wallet::sync()
}

pub fn get_address() -> Result<Address> {
    Ok(Address::new(wallet::get_address()?.to_string()))
}

pub fn maker_peer_info() -> String {
    config::maker_peer_info().to_string()
}

pub fn node_id() -> String {
    wallet::node_id().to_string()
}

pub fn network() -> SyncReturn<String> {
    SyncReturn(config::network().to_string())
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_channel(taker_amount: u64) -> Result<()> {
    let peer_info = config::maker_peer_info();
    wallet::open_channel(peer_info, taker_amount).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn close_channel() -> Result<()> {
    let peer_info = config::maker_peer_info();
    wallet::close_channel(peer_info.pubkey, false).await
}

pub fn send_to_address(address: String, amount: u64) -> Result<String> {
    anyhow::ensure!(!address.is_empty(), "cannot send to an empty address");
    let address = address.parse()?;

    let txid = wallet::send_to_address(address, amount)?;
    let txid = txid.to_string();

    Ok(txid)
}

#[tokio::main(flavor = "current_thread")]
pub async fn list_cfds() -> Result<Vec<Cfd>> {
    let mut conn = db::acquire().await?;
    cfd::load_cfds(&mut conn).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_cfd(order: Order) -> Result<()> {
    cfd::open(&order).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn call_faucet(address: String) -> Result<String> {
    anyhow::ensure!(
        !address.is_empty(),
        "Cannot call faucet because of empty address"
    );
    faucet::call_faucet(address).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn get_fee_recommendation() -> Result<u32> {
    let fee_recommendation = wallet::get_fee_recommendation()?;

    Ok(fee_recommendation)
}

/// Settles a CFD with the given taker and maker amounts in sats
#[tokio::main(flavor = "current_thread")]
pub async fn settle_cfd(cfd: Cfd, offer: Offer) -> Result<()> {
    cfd::settle(&cfd, &offer).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn get_lightning_tx_history() -> Result<Vec<LightningTransaction>> {
    wallet::get_lightning_history().await
}

/// Initialise logging infrastructure for Rust
pub fn init_logging(sink: StreamSink<logger::LogEntry>) {
    logger::create_log_stream(sink)
}

pub fn get_seed_phrase() -> Vec<String> {
    // The flutter rust bridge generator unfortunately complains when wrapping a ZeroCopyBuffer with
    // a Result. Hence we need to copy here (data isn't too big though, so that should be ok).
    wallet::get_seed_phrase()
}

#[tokio::main(flavor = "current_thread")]
pub async fn send_lightning_payment(invoice: String) -> Result<()> {
    anyhow::ensure!(!invoice.is_empty(), "Cannot pay empty invoice");
    wallet::send_lightning_payment(&invoice).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn create_lightning_invoice(
    amount_sats: u64,
    expiry_secs: u32,
    description: String,
) -> Result<String> {
    wallet::create_invoice(amount_sats, expiry_secs, description).await
}

// Note, this implementation has to be on the api level as otherwise it wouldn't be generated
// through frb. TODO: Provide multiple rust targets to the code generation so that this code can be
// nicer structured.
impl Order {
    /// Calculate the taker's margin in BTC.
    pub fn margin_taker(&self) -> SyncReturn<f64> {
        SyncReturn(Self::calculate_margin(
            self.open_price,
            self.quantity,
            self.leverage,
        ))
    }

    /// Calculate the total margin in BTC.
    pub(crate) fn margin_total(&self) -> f64 {
        let margin_taker = self.margin_taker().0;
        let margin_maker = self.margin_maker();

        margin_taker + margin_maker
    }

    /// Calculate the maker's margin in BTC.
    fn margin_maker(&self) -> f64 {
        Self::calculate_margin(self.open_price, self.quantity, 1)
    }

    /// Calculate the margin in BTC.
    fn calculate_margin(opening_price: f64, quantity: i64, leverage: i64) -> f64 {
        let quantity = Decimal::from(quantity);
        let open_price = Decimal::try_from(opening_price).expect("to fit into decimal");
        let leverage = Decimal::from(leverage);

        if open_price == Decimal::ZERO || leverage == Decimal::ZERO {
            // just to avoid div by 0 errors
            return 0.0;
        }

        let margin = quantity / (open_price * leverage);
        let margin =
            margin.round_dp_with_strategy(8, rust_decimal::RoundingStrategy::MidpointAwayFromZero);
        margin.to_f64().expect("price to fit into f64")
    }

    pub fn calculate_expiry(&self) -> SyncReturn<i64> {
        SyncReturn(
            OffsetDateTime::now_utc()
                .saturating_add(Duration::days(30))
                .unix_timestamp(),
        )
    }

    pub fn calculate_liquidation_price(&self) -> SyncReturn<f64> {
        let initial_price = Decimal::try_from(self.open_price).expect("Price to fit");

        tracing::trace!("Initial price: {}", self.open_price);

        let leverage = Decimal::from(self.leverage);

        let liquidation_price = match self.position {
            Position::Long => {
                calc::inverse::calculate_long_liquidation_price(leverage, initial_price)
            }
            Position::Short => {
                calc::inverse::calculate_short_liquidation_price(leverage, initial_price)
            }
        };

        let liquidation_price = liquidation_price.to_f64().expect("price to fit into f64");
        tracing::trace!("Liquidation_price: {liquidation_price}");

        SyncReturn(liquidation_price)
    }

    /// Calculate the profit or loss in BTC.
    pub fn calculate_profit_taker(&self, closing_price: f64) -> Result<SyncReturn<f64>> {
        let margin = self.margin_taker().0;
        let payout = self.calculate_payout_at_price(closing_price)?;
        let pnl = payout - margin;

        tracing::trace!(%pnl, %payout, %margin,"Calculated taker's PnL");

        Ok(SyncReturn(pnl))
    }

    pub(crate) fn calculate_payout_at_price(&self, closing_price: f64) -> Result<f64> {
        let uncapped_pnl_long = {
            let opening_price = Decimal::try_from(self.open_price)?;
            let closing_price = Decimal::try_from(closing_price)?;

            if opening_price == Decimal::ZERO || closing_price == Decimal::ZERO {
                return Ok(0.0);
            }

            let quantity = Decimal::from(self.quantity);

            let uncapped_pnl = (quantity / opening_price) - (quantity / closing_price);
            let uncapped_pnl = uncapped_pnl
                .round_dp_with_strategy(8, rust_decimal::RoundingStrategy::MidpointAwayFromZero);
            uncapped_pnl
                .to_f64()
                .context("Could not convert Decimal to f64")?
        };

        let margin = self.margin_taker().0;
        let payout = match self.position {
            Position::Long => margin + uncapped_pnl_long,
            Position::Short => margin - uncapped_pnl_long,
        };

        let payout = payout.max(0.0);
        let payout = payout.min(self.margin_total());

        Ok(payout)
    }
}
