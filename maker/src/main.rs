use std::env::temp_dir;

use maker::logger;
use ten_ten_one::wallet;
use tracing::metadata::LevelFilter;

#[tokio::main]
async fn main() {
    let path = temp_dir();
    logger::init_tracing(LevelFilter::DEBUG, false).expect("Logger to initialise");
    // TODO: pass in wallet parameters via clap
    wallet::init_wallet(wallet::Network::Regtest, path.as_path()).expect("wallet to initialise");
    let port = 9045;
    let (tcp_handle, _background_processor) = wallet::run_ldk_server(port)
        .await
        .expect("lightning network to run");

    let public_key = wallet::node_id().expect("To get node id for maker");
    let listening_address = format!("{public_key}@127.0.0.1:{port}");
    tracing::info!(listening_address, "Listening on");
    let address = wallet::get_address()
        .expect("To get a new address")
        .to_string();
    tracing::info!(address, "New address");

    tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    let balance = wallet::get_balance().unwrap();
    tracing::info!("Balance {balance:?}");
    let _ = tcp_handle.await;
}
