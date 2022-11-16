use anyhow::Result;
use maker::logger;
use maker::routes;
use std::env::temp_dir;
use std::time::Duration;
use ten_ten_one::wallet;
use tracing::metadata::LevelFilter;

#[rocket::main]
async fn main() -> Result<()> {
    let path = temp_dir();
    logger::init_tracing(LevelFilter::DEBUG, false)?;
    // TODO: pass in wallet parameters via clap
    wallet::init_wallet(wallet::Network::Regtest, path.as_path())?;
    let port = 9045;

    tokio::spawn(async move {
        let (_tcp_handle, _background_processor) = wallet::run_ldk_server(port)
            .await
            .expect("lightning network to run");

        let public_key = wallet::node_id().expect("To get node id for maker");
        let listening_address = format!("{public_key}@127.0.0.1:{port}");
        tracing::info!(listening_address, "Listening on");
        let address = wallet::get_address()
            .expect("To get a new address")
            .to_string();
        tracing::info!(address, "New address");

        loop {
            match wallet::get_balance() {
                Ok(balance) => tracing::info!(?balance, "Current balance"),
                Err(e) => tracing::error!("Could not retrieve balance: {e:#}"),
            }
            tokio::time::sleep(Duration::from_secs(10)).await;
        }
    });

    let mission_success = rocket::build()
        .mount(
            "/api",
            rocket::routes![routes::get_offers, routes::post_force_close_channel],
        )
        .launch()
        .await?;

    tracing::trace!(?mission_success, "Rocket has landed");

    Ok(())
}
