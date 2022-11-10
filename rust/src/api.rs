use crate::disk::parse_peer_info;
use crate::logger;
use crate::wallet;
use crate::wallet::Network;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use std::path::Path;
use tokio::runtime::Runtime;

pub struct Balance {
    pub confirmed: u64,
}

impl Balance {
    pub fn new(confirmed: u64) -> Balance {
        Balance { confirmed }
    }
}

pub fn init_wallet(network: Network, path: String) -> Result<()> {
    let rt = Runtime::new()?;
    rt.block_on(async { wallet::init_wallet(network, Path::new(path.as_str()), 9735).await })
}

pub fn get_balance() -> Result<Balance> {
    Ok(Balance::new(wallet::get_balance()?.confirmed))
}

pub fn open_channel(
    peer_pubkey_and_ip_addr: String,
    channel_amount_sat: u64,
    path: String,
) -> Result<()> {
    let peer_info = parse_peer_info(peer_pubkey_and_ip_addr)?;
    let rt = Runtime::new()?;
    rt.block_on(async {
        wallet::open_channel(peer_info, channel_amount_sat, Path::new(path.as_str())).await
    })
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

#[cfg(test)]
mod tests {

    use crate::api::init_wallet;
    use std::env::temp_dir;

    use super::Network;

    #[test]
    fn wallet_support_for_different_bitcoin_networks() {
        // TODO: we should rethink these tests, as they aren't simple unit tests anymore.
        init_wallet(Network::Mainnet, temp_dir().to_string_lossy().to_string())
            .expect("wallet to be initialized");
        init_wallet(Network::Testnet, temp_dir().to_string_lossy().to_string())
            .expect("wallet to be initialized");
        init_wallet(Network::Regtest, temp_dir().to_string_lossy().to_string())
            .expect_err("wallet should not succeed to initialize");
    }
}
