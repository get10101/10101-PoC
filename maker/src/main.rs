use anyhow::Result;
use maker::bitmex;
use maker::cli::Opts;
use maker::logger;
use maker::routes;
use std::time::Duration;
use ten_ten_one::db;
use ten_ten_one::wallet;
use tracing::metadata::LevelFilter;

#[rocket::main]
async fn main() -> Result<()> {
    let opts = Opts::read();

    let path = opts.data_dir()?;
    let network = opts.network();
    let lightning_p2p_address = opts.lightning_p2p_address;
    let http_address = opts.http_address;
    let electrum_url = opts.electrum();

    logger::init_tracing(LevelFilter::DEBUG, false)?;
    wallet::init_wallet(network.clone(), electrum_url.as_str(), path.as_path())?;

    db::init_db(&path.join(network.to_string()).join("maker.sqlite"))
        .await
        .expect("maker db to initialise");

    let connection = db::acquire().await.unwrap();
    tracing::info!(?connection);

    tokio::spawn(async move {
        let (_tcp_handle, _background_processor) = wallet::run_ldk_server(lightning_p2p_address)
            .await
            .expect("lightning node to run");

        let public_key = wallet::node_id().expect("To get node id for maker");
        let listening_address = format!("{public_key}@{lightning_p2p_address}");
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

    let (_, quote_receiver) = bitmex::subscribe()?;

    let figment = rocket::Config::figment()
        .merge(("address", http_address.ip()))
        .merge(("port", http_address.port()));

    let mission_success = rocket::custom(figment)
        .mount(
            "/api",
            rocket::routes![
                routes::get_offer,
                routes::post_force_close_channel,
                routes::post_open_channel
            ],
        )
        .manage(quote_receiver)
        .launch()
        .await?;

    tracing::trace!(?mission_success, "Rocket has landed");

    Ok(())
}
