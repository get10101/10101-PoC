use crate::lightning::PeerInfo;
use crate::logger;
use crate::offer;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::Balance;
use crate::wallet::Network;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use flutter_rust_bridge::StreamSink;
use state::Storage;
use std::path::Path;
use std::sync::Mutex;
use std::sync::MutexGuard;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;
use tokio::runtime::Runtime;

static CONFIG: Storage<Mutex<Config>> = Storage::new();

fn get_config() -> Result<MutexGuard<'static, Config>> {
    CONFIG
        .try_get()
        .context("Config uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire config lock"))
}

#[frb]
#[derive(Clone)]
pub struct Config {
    pub network: Network,
    pub endpoint: String,
    pub lightning_port: u16,
    pub http_port: u16,
    pub maker_public_key: String,
    #[frb(non_final)]
    pub data_dir: Option<String>,
}

impl Config {
    fn get_data_dir(&self) -> Result<&Path> {
        match &self.data_dir {
            Some(data_dir) => Ok(Path::new(data_dir.as_str())),
            None => bail!("Missing data dir"),
        }
    }

    pub fn get_p2p_endpoint(&self) -> String {
        format!(
            "{}@{}:{}",
            self.maker_public_key, self.endpoint, self.lightning_port
        )
    }

    pub fn get_http_endpoint(&self) -> String {
        format!("http://{}:{}", self.endpoint, self.http_port)
    }

    fn get_peer_info(&self) -> PeerInfo {
        PeerInfo {
            pubkey: self
                .maker_public_key
                .parse()
                .expect("maker public key to be valid"),
            peer_addr: format!("{}:{}", self.endpoint, self.lightning_port)
                .parse()
                .expect("Hard-coded PK to be valid"),
        }
    }
}

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

pub fn init_wallet(config: Config) -> Result<()> {
    CONFIG.set(Mutex::new(config.clone()));
    wallet::init_wallet(config.clone().network, config.get_data_dir()?)
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

pub fn open_channel(channel_amount_sat: u64) -> Result<()> {
    let config = { (*get_config()?).clone() };
    let peer_info = config.get_peer_info();

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
pub async fn open_cfd(taker_amount: u64, leverage: u64) -> Result<()> {
    if leverage > 2 {
        bail!("Only leverage x1 and x2 are supported at the moment");
    }

    // Hardcoded leverage of 2
    let maker_amount = taker_amount.saturating_mul(leverage);

    let config = (*get_config()?).clone();
    wallet::open_cfd(
        taker_amount,
        maker_amount,
        &config.maker_public_key,
        &config.get_p2p_endpoint(),
        &config.get_http_endpoint(),
    )
    .await?;

    Ok(())
}

pub fn get_offer() -> Result<Offer> {
    let rt = Runtime::new()?;
    rt.block_on(async {
        let config = { (*get_config()?).clone() };
        offer::get_offer(&config.get_http_endpoint()).await
    })
}

#[tokio::main(flavor = "current_thread")]
pub async fn settle_cfd(taker_amount: u64, maker_amount: u64) -> Result<()> {
    wallet::settle_cfd(taker_amount, maker_amount).await?;
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
    use crate::api::Config;
    use crate::wallet::Network;

    #[test]
    fn wallet_support_for_different_bitcoin_networks() {
        let dummy_config = Config {
            network: Network::Mainnet,
            endpoint: "127.0.0.1".to_string(),
            lightning_port: 9045,
            http_port: 8000,
            maker_public_key: "pubkey".to_string(),
            data_dir: Some("".to_string()),
        };
        init_wallet(dummy_config.clone()).expect("wallet to be initialized");
        init_wallet(Config {
            network: Network::Testnet,
            ..dummy_config.clone()
        })
        .expect("wallet to be initialized");
        init_wallet(Config {
            network: Network::Regtest,
            ..dummy_config
        })
        .expect_err("wallet should not succeed to initialize");
    }
}
