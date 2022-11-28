use crate::calc;
use crate::cfd;
use crate::cfd::models::Cfd;
use crate::cfd::models::Order;
use crate::cfd::models::Position;
use crate::config;
use crate::db;
use crate::logger;
use crate::offer;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::Balance;
use crate::wallet::LightningTransaction;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use flutter_rust_bridge::SyncReturn;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use std::path::Path;
use time::Duration;
pub use time::OffsetDateTime;

pub struct Address {
    pub address: String,
}

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

#[tokio::main(flavor = "current_thread")]
pub async fn init_db(app_dir: String) -> Result<()> {
    let network = config::network();
    db::init_db(
        &Path::new(app_dir.as_str())
            .join(network.to_string())
            .join("taker.sqlite"),
    )
    .await
}

/// Test DB operation running from Flutter
// FIXME: remove this call and instead use DB meaningfully - this is just a test whether the DB
// works with Flutter and this
#[tokio::main(flavor = "current_thread")]
pub async fn test_db_connection() -> Result<()> {
    let connection = db::acquire().await?;
    tracing::info!(?connection);
    Ok(())
}

pub fn init_wallet(path: String) -> Result<()> {
    wallet::init_wallet(Path::new(path.as_str()))
}

#[tokio::main(flavor = "current_thread")]
pub async fn run_ldk() -> Result<()> {
    tracing::debug!("Starting ldk node");
    match wallet::run_ldk().await {
        Ok(background_processor) => {
            // await background processor here as otherwise the spawned thread gets dropped
            let _ = background_processor.join();
        }
        Err(err) => {
            tracing::error!("Error running LDK: {err}");
        }
    }
    Ok(())
}

pub fn get_balance() -> Result<Balance> {
    wallet::get_balance()
}

pub fn get_address() -> Result<Address> {
    Ok(Address::new(wallet::get_address()?.to_string()))
}

pub fn maker_peer_info() -> String {
    config::maker_peer_info().to_string()
}

#[tokio::main(flavor = "current_thread")]
pub async fn connect() -> Result<()> {
    let mut connected = false;
    loop {
        tracing::trace!("Checking if maker is alive");
        let client = reqwest::Client::builder()
            .timeout(crate::config::TCP_TIMEOUT)
            .build()?;
        let result = client
            .get(config::maker_endpoint() + "/api/alive")
            .send()
            .await;

        match result {
            Ok(_) => {
                if !connected {
                    let result = wallet::connect().await;
                    match result {
                        Ok(()) => {
                            tracing::info!("Successfully connected to maker");
                            connected = true;
                        }
                        Err(err) => {
                            tracing::warn!("Failed to connect to maker! {err:?}");
                            connected = false;
                        }
                    }
                }
            }
            Err(err) => {
                tracing::warn!("Maker is offline! {err:?}");
                connected = false;
            }
        };

        // looping here indefinitely to keep the connection with the maker alive.
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_channel(taker_amount: u64) -> Result<()> {
    let peer_info = config::maker_peer_info();
    wallet::open_channel(peer_info, taker_amount).await
}

pub fn send_to_address(address: String, amount: u64) -> Result<String> {
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
pub async fn get_offer() -> Result<Option<Offer>> {
    offer::get_offer().await
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
pub async fn get_bitcoin_tx_history() -> Result<Vec<BitcoinTxHistoryItem>> {
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

pub fn get_lightning_tx_history() -> Result<Vec<LightningTransaction>> {
    wallet::get_lightning_history()
}

/// Initialise logging infrastructure for Rust
pub fn init_logging(sink: StreamSink<logger::LogEntry>) {
    logger::create_log_stream(sink)
}

pub fn get_seed_phrase() -> Result<Vec<String>> {
    // The flutter rust bridge generator unfortunately complains when wrapping a ZeroCopyBuffer with
    // a Result. Hence we need to copy here (data isn't too big though, so that should be ok).
    wallet::get_seed_phrase()
}

pub fn send_lightning_payment(invoice: String) -> Result<()> {
    wallet::send_lightning_payment(&invoice)
}

pub fn create_lightning_invoice(
    amount_sats: u64,
    expiry_secs: u32,
    description: String,
) -> Result<String> {
    wallet::create_invoice(amount_sats, expiry_secs, description)
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
                .saturating_add(Duration::days(1))
                .unix_timestamp(),
        )
    }

    pub fn calculate_liquidation_price(&self) -> SyncReturn<f64> {
        let initial_price = Decimal::try_from(self.open_price).expect("Price to fit");

        tracing::debug!("Initial price: {}", self.open_price);

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
        tracing::info!("Liquidation_price: {liquidation_price}");

        SyncReturn(liquidation_price)
    }

    /// Calculate the profit or loss in BTC.
    pub fn calculate_profit_taker(&self, closing_price: f64) -> Result<SyncReturn<f64>> {
        let margin = self.margin_taker().0;
        let payout = self.calculate_payout_at_price(closing_price)?;
        let pnl = payout - margin;

        tracing::debug!(%pnl, %payout, %margin,"Calculated taker's PnL");

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
