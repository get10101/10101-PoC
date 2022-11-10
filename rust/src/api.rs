use crate::logger;
use crate::wallet;
use crate::wallet::Network;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use std::path::Path;

pub struct Balance {
    pub confirmed: u64,
}

impl Balance {
    pub fn new(confirmed: u64) -> Balance {
        Balance { confirmed }
    }
}

pub fn init_wallet(network: Network, path: String) -> Result<()> {
    wallet::init_wallet(network, Path::new(path.as_str()), 9735)
}

pub fn get_balance() -> Result<Balance> {
    Ok(Balance::new(wallet::get_balance()?.confirmed))
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
