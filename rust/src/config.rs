use crate::lightning::PeerInfo;
use anyhow::bail;
use anyhow::Result;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::Network;
use std::time::Duration;

const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";
const REGTEST_ELECTRUM: &str = "tcp://localhost:50000";

static REGTEST_MAKER_IP: &str = "127.0.0.1";
static REGTEST_MAKER_PORT_HTTP: u64 = 8000;
// Maker PK is derived from our checked in regtest maker seed
static REGTEST_MAKER_PK: &str =
    "02cb6517193c466de0688b8b0386dbfb39d96c3844525c1315d44bd8e108c08bc1";

static MAKER_PORT_LIGHTNING: u64 = 9045;

static TESTNET_MAKER_IP: &str = "35.189.57.114"; // testnet.itchysats.network
static TESTNET_MAKER_PORT_HTTP: u64 = 8888;
// Maker PK logged in tentenone-maker testnet container
static TESTNET_MAKER_PK: &str =
    "0244946473b7926c427be70925e8e99cafc3ea76dffe708e6cba8896576cf0b14d";

pub static TCP_TIMEOUT: Duration = Duration::from_secs(10);

/// Network the app is running
///
/// Defaults to testnet if nothing is specified
pub fn network() -> Network {
    read_network_from_env().unwrap_or(Network::Testnet)
}

pub fn electrum_url() -> String {
    match network() {
        Network::Bitcoin => MAINNET_ELECTRUM,
        Network::Testnet => TESTNET_ELECTRUM,
        Network::Signet => todo!(),
        Network::Regtest => REGTEST_ELECTRUM,
    }
    .to_string()
}

pub fn maker_pk() -> PublicKey {
    match network() {
        Network::Testnet => TESTNET_MAKER_PK.parse().expect("Hard-coded PK to be valid"),
        Network::Regtest => REGTEST_MAKER_PK.parse().expect("Hard-coded PK to be valid"),
        Network::Signet => todo!(),
        Network::Bitcoin => todo!(),
    }
}

fn maker_ip() -> String {
    match network() {
        Network::Bitcoin => todo!(),
        Network::Testnet => TESTNET_MAKER_IP.to_string(),
        Network::Signet => todo!(),
        Network::Regtest => REGTEST_MAKER_IP.to_string(),
    }
}

fn maker_port_http() -> u64 {
    match network() {
        Network::Bitcoin => todo!(),
        Network::Testnet => TESTNET_MAKER_PORT_HTTP,
        Network::Signet => todo!(),
        Network::Regtest => REGTEST_MAKER_PORT_HTTP,
    }
}

pub fn maker_endpoint() -> String {
    let ip = maker_ip();
    let http = maker_port_http();
    format!("http://{ip}:{http}")
}

pub fn maker_peer_info() -> PeerInfo {
    let ip = maker_ip();
    PeerInfo {
        pubkey: maker_pk(),
        peer_addr: format!("{ip}:{MAKER_PORT_LIGHTNING}")
            .parse()
            .expect("Hard-coded IP and port to be valid"),
    }
}

/// Parse bitcoin network from command line, e.g. NETWORK=testnet
fn read_network_from_env() -> Result<Network> {
    let network = match std::env::var_os("NETWORK") {
        Some(s) => s.into_string(),
        None => bail!("ENV variable not set"),
    }
    .expect("to be valid unicode");
    from_network_str(&network)
}

fn from_network_str(s: &str) -> Result<Network> {
    match s {
        "testnet" => Ok(Network::Testnet),
        "regtest" => Ok(Network::Regtest),
        "mainnet" => Ok(Network::Bitcoin),
        "bitcoin" => Ok(Network::Bitcoin),
        "signet" => Ok(Network::Signet),
        _ => bail!("Unsupported network"),
    }
}
