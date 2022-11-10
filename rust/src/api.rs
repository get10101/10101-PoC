use crate::hex_utils;
use crate::lightning::PeerInfo;
use crate::logger;
use crate::wallet;
use crate::wallet::Network;
use anyhow::bail;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use std::net::ToSocketAddrs;
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
    wallet::init_wallet(network, Path::new(path.as_str()), 9735)
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

pub(crate) fn parse_peer_info(peer_pubkey_and_ip_addr: String) -> Result<PeerInfo> {
    let mut pubkey_and_addr = peer_pubkey_and_ip_addr.split('@');
    let pubkey = pubkey_and_addr.next();
    let peer_addr_str = pubkey_and_addr.next();
    if peer_addr_str.is_none() || peer_addr_str.is_none() {
        bail!("ERROR: incorrectly formatted peer info. Should be formatted as: `pubkey@host:port`");
    }

    let peer_addr = peer_addr_str
        .unwrap()
        .to_socket_addrs()
        .map(|mut r| r.next());
    if peer_addr.is_err() || peer_addr.as_ref().unwrap().is_none() {
        bail!("ERROR: couldn't parse pubkey@host:port into a socket address");
    }

    let pubkey = hex_utils::to_compressed_pubkey(pubkey.unwrap());
    if pubkey.is_none() {
        bail!("ERROR: unable to parse given pubkey for node");
    }

    Ok(PeerInfo {
        pubkey: pubkey.unwrap(),
        peer_addr: peer_addr.unwrap().unwrap(),
    })
}
