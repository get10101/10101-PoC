use crate::logger;
use crate::wallet;
use crate::wallet::Network;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;

pub struct Balance {
    pub confirmed: u64,
}

impl Balance {
    pub fn new(confirmed: u64) -> Balance {
        Balance { confirmed }
    }
}

pub fn init_wallet(network: Network) -> Result<()> {
    wallet::init_wallet(network)
}

pub fn get_balance() -> anyhow::Result<Balance> {
    Ok(Balance::new(wallet::get_balance()?.confirmed))
}

/// Initialise logging infrastructure for Rust
pub fn init_logging(sink: StreamSink<logger::LogEntry>) {
    logger::create_log_stream(sink)
}
