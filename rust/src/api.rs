use crate::calc;
use crate::cfd;
use crate::cfd::Cfd;
use crate::cfd::ContractSymbol;
use crate::cfd::Position;
use crate::db;
use crate::logger;
use crate::offer;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::Balance;
use crate::wallet::LightningTransaction;
use crate::wallet::Network;
use crate::wallet::MAINNET_ELECTRUM;
use crate::wallet::REGTEST_ELECTRUM;
use crate::wallet::TESTNET_ELECTRUM;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use flutter_rust_bridge::SyncReturn;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use std::path::Path;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

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
pub async fn init_db(app_dir: String, network: Network) -> Result<()> {
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

pub fn init_wallet(network: Network, path: String) -> Result<()> {
    let electrum_url = match network {
        Network::Mainnet => MAINNET_ELECTRUM,
        Network::Testnet => TESTNET_ELECTRUM,
        Network::Regtest => REGTEST_ELECTRUM,
    };
    wallet::init_wallet(network, electrum_url, Path::new(path.as_str()))
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
    wallet::maker_peer_info().to_string()
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_channel(taker_amount: u64) -> Result<()> {
    let peer_info = wallet::maker_peer_info();
    // TODO: stream updates back to the UI (if possible)?
    if let Err(e) = wallet::open_channel(peer_info, taker_amount).await {
        tracing::error!("Unable to open channel: {e:#}")
    }
    loop {
        // looping here indefinitely to keep the connection with the maker alive.
        tokio::time::sleep(Duration::from_secs(1000)).await;
    }
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
    let cfds = db::load_cfds(&mut conn).await?;

    Ok(cfds)
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_cfd(order: cfd::Order) -> Result<()> {
    cfd::open(&order).await
}

#[tokio::main(flavor = "current_thread")]
pub async fn get_offer() -> Result<Offer> {
    offer::get_offer().await
}

#[tokio::main(flavor = "current_thread")]
pub async fn settle_cfd(taker_amount: u64, maker_amount: u64) -> Result<()> {
    cfd::settle(taker_amount, maker_amount).await
}

pub fn get_bitcoin_tx_history() -> Result<Vec<BitcoinTxHistoryItem>> {
    let tx_history = wallet::get_bitcoin_tx_history()?
        .into_iter()
        .map(|tx| {
            let (is_confirmed, timestamp) = match tx.confirmation_time {
                None => (
                    false,
                    SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .expect("current timestamp to be valid")
                        .as_secs(),
                ),
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

pub fn calculate_liquidation_price(
    initial_price: f64,
    leverage: i64,
    position: Position,
    contract_symbol: ContractSymbol,
) -> SyncReturn<f64> {
    let initial_price = Decimal::try_from(initial_price).expect("Price to fit");

    tracing::debug!("Initial price: {initial_price}");

    let leverage = Decimal::from(leverage);

    let liquidation_price = match (contract_symbol, position) {
        (ContractSymbol::BtcUsd, Position::Long) => {
            calc::inverse::calculate_long_liquidation_price(leverage, initial_price)
        }
        (ContractSymbol::BtcUsd, Position::Short) => {
            calc::inverse::calculate_short_liquidation_price(leverage, initial_price)
        }
        (ContractSymbol::EthUsd, Position::Long) => {
            calc::quanto::bankruptcy_price_long(initial_price, leverage)
        }
        (ContractSymbol::EthUsd, Position::Short) => {
            calc::quanto::bankruptcy_price_short(initial_price, leverage)
        }
    };

    let liquidation_price = liquidation_price.to_f64().expect("price to fit into f64");
    tracing::info!("Liquidation_price: {liquidation_price}");

    SyncReturn(liquidation_price)
}

// Tests are in the api layer as they became rather integration than unit tests (and need the
// runtime) TODO: Move them to `tests` directory
#[cfg(test)]
mod tests {

    use crate::api::init_wallet;
    use std::env::temp_dir;

    use super::Network;

    #[test]
    fn wallet_support_for_different_bitcoin_networks() {
        init_wallet(Network::Mainnet, temp_dir().to_string_lossy().to_string())
            .expect("wallet to be initialized");
        init_wallet(Network::Testnet, temp_dir().to_string_lossy().to_string())
            .expect("wallet to be initialized");
        init_wallet(Network::Regtest, temp_dir().to_string_lossy().to_string())
            .expect_err("wallet should not succeed to initialize");
    }
}
