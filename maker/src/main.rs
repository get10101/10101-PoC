use anyhow::Result;
use bdk::bitcoin::Network;
use maker::bitmex;
use maker::cli::Opts;
use maker::logger;
use maker::routes;
use maker::routes::SpreadPrice;
use std::time::Duration;
use std::time::Instant;
use ten_ten_one::db;
use ten_ten_one::wallet;
use tokio::sync::watch;
use tracing::metadata::LevelFilter;

#[rocket::main]
async fn main() -> Result<()> {
    let opts = Opts::read();

    let path = opts.data_dir()?;
    let lightning_p2p_address = opts.lightning_p2p_address;
    let http_address = opts.http_address;

    logger::init_tracing(LevelFilter::DEBUG, false)?;
    wallet::init_wallet(path.as_path())?;

    let network = ten_ten_one::config::network();
    db::init_db(&path.join(network.to_string()).join("maker.sqlite"))
        .await
        .expect("maker db to initialise");

    let connection = db::acquire().await.unwrap();
    tracing::info!(?connection);

    tokio::spawn(async move {
        let (_tcp_handle, _background_processor) = wallet::run_ldk_server(lightning_p2p_address)
            .await
            .expect("lightning node to run");

        let node_info = wallet::get_node_info();
        let public_key = node_info.node_id;
        let listening_address = format!("{public_key}@{lightning_p2p_address}");
        tracing::info!(listening_address, "Listening on");
        let address = wallet::get_address()
            .expect("To get a new address")
            .to_string();
        tracing::info!(address, "New address");

        loop {
            let started = Instant::now();

            if let Err(e) = wallet::sync() {
                tracing::error!("Wallet sync failed: {e:#}");
            }

            let wallet_result = wallet::get_balance();
            let duration = started.elapsed();
            let sync_time_in_seconds = duration.as_secs();
            match wallet_result {
                Ok(balance) => tracing::info!(?balance, sync_time_in_seconds, "Current balance"),
                Err(e) => {
                    tracing::error!(sync_time_in_seconds, "Could not retrieve balance: {e:#}")
                }
            }
            let sync_time = match network {
                Network::Bitcoin => 5 * 60,
                Network::Testnet => 2 * 60,
                Network::Signet => 60,
                Network::Regtest => 30,
            };
            tokio::time::sleep(Duration::from_secs(sync_time)).await;
        }
    });

    let (_, quote_receiver) = bitmex::subscribe()?;

    let (spread_sender, spread_receiver) = watch::channel(SpreadPrice::new(15));

    let figment = rocket::Config::figment()
        .merge(("address", http_address.ip()))
        .merge(("port", http_address.port()));

    let mission_success = rocket::custom(figment)
        .mount(
            "/api",
            rocket::routes![
                routes::get_offer,
                routes::post_close_channel,
                routes::post_open_channel,
                routes::post_pay_invoice,
                routes::post_send_to_address,
                routes::get_new_invoice,
                routes::get_wallet_details,
                routes::get_channel_details,
                routes::get_node_info,
                routes::get_spread,
                routes::put_spread,
                routes::alive,
                routes::get_faucet,
            ],
        )
        .manage(quote_receiver)
        .manage(spread_sender)
        .manage(spread_receiver)
        .launch()
        .await?;

    tracing::trace!(?mission_success, "Rocket has landed");

    Ok(())
}
