use std::env::temp_dir;

use maker::logger;
use ten_ten_one::wallet;
use tracing::metadata::LevelFilter;

#[tokio::main]
async fn main() {
    let path = temp_dir();
    logger::init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
    // TODO: pass in wallet parameters via clap
    wallet::init_wallet(wallet::Network::Testnet, path.as_path()).expect("wallet to initialise");
    let _ = wallet::run_ldk().await.expect("lightning node to run");
}
