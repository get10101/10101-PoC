use std::env::temp_dir;
use time::Duration;

use maker::logger;
use ten_ten_one::wallet;
use tracing::metadata::LevelFilter;

#[tokio::main]
async fn main() {
    let path = temp_dir();
    logger::init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
    // TODO: pass in wallet parameters via clap
    wallet::init_wallet(wallet::Network::Regtest, path.as_path()).expect("wallet to initialise");
    wallet::run_ldk(9045)
        .await
        .expect("lightning network to run");

    let address = wallet::get_address().unwrap();
    tracing::info!("New address {address}");

    loop  {
      // nothing to see here
        tokio::time::sleep(std::time::Duration::from_secs(10)).await;
        let balance = wallet::get_balance().unwrap();
        tracing::info!("Balance {balance}");
    };
}
