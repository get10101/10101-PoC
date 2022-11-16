use crate::disk::parse_peer_info;
use crate::logger;
use crate::wallet;
use crate::wallet::Balance;
use crate::wallet::Network;
use anyhow::bail;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use std::path::Path;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;
use tokio::runtime::Runtime;

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

pub fn init_wallet(network: Network, path: String) -> Result<()> {
    wallet::init_wallet(network, Path::new(path.as_str()))
}

pub fn run_ldk() -> Result<()> {
    tracing::debug!("Starting ldk node");
    let rt = Runtime::new()?;
    rt.block_on(async move {
        match wallet::run_ldk().await {
            Ok(background_processor) => {
                // await background processor here as otherwise the spawned thread gets dropped
                let _ = background_processor.join();
            }
            Err(err) => {
                tracing::error!("Error running LDK: {err}");
            }
        }
    });
    Ok(())
}

pub fn get_balance() -> Result<Balance> {
    wallet::get_balance()
}

pub fn get_address() -> Result<Address> {
    Ok(Address::new(wallet::get_address()?.to_string()))
}

pub fn open_channel(peer_pubkey_and_ip_addr: String, channel_amount_sat: u64) -> Result<()> {
    let peer_info = parse_peer_info(peer_pubkey_and_ip_addr)?;
    let rt = Runtime::new()?;
    rt.block_on(async {
        if let Err(e) = wallet::open_channel(peer_info, channel_amount_sat).await {
            tracing::error!("Unable to open channel: {e:#}")
        }
        loop {
            // looping here indefinitely to keep the connection with the maker alive.
            tokio::time::sleep(Duration::from_secs(1000)).await;
        }
    });
    Ok(())
}

#[tokio::main(flavor = "current_thread")]
pub async fn open_cfd(taker_amount: u64, leverage: u64, maker_ip_port: String) -> Result<()> {
    if leverage > 2 {
        bail!("Only leverage x1 and x2 are supported at the moment");
    }

    // Hardcoded leverage of 2
    let maker_amount = taker_amount.saturating_mul(leverage);

    wallet::open_cfd(taker_amount, maker_amount, maker_ip_port).await?;

    Ok(())
}

pub fn get_bitcoin_tx_history() -> Result<Vec<BitcoinTxHistoryItem>> {
    let mut tx_history = wallet::get_bitcoin_tx_history()?
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

    tx_history.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

    Ok(tx_history)
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
