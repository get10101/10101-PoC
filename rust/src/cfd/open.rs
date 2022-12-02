use crate::cfd::dal;
use crate::cfd::models::Order;
use crate::config::maker_pk;
use crate::db;
use crate::wallet;
use anyhow::anyhow;
use anyhow::Context;
use anyhow::Result;

pub async fn open(order: &Order) -> Result<()> {
    let liquidation_price: f64 = order.calculate_liquidation_price().0;
    let expiry = order.calculate_expiry().0;

    let margin_taker_as_btc = order.margin_taker().0;
    // Convert to msats
    let margin_taker = (margin_taker_as_btc * 100_000_000.0 * 1000.0) as u64;
    let margin_maker = margin_taker * order.leverage as u64;

    tracing::info!(
        quantity = order.quantity,
        margin_taker,
        margin_maker,
        "Opening CFD",
    );

    let channel_manager = wallet::get_channel_manager()?;
    let channels = channel_manager.list_channels();

    tracing::info!("Channels: {channels:?}");

    let channel_details = channels
        .iter()
        .find(|ch| ch.counterparty.node_id == maker_pk())
        .context("no open channel with maker found")?;

    let maker_pk = channel_details.counterparty.node_id;
    let short_channel_id = channel_details
        .short_channel_id
        .context("Cannot create custom output if funding transaction has not yet been confirmed")?;

    // hardcoded because we are not dealing with force-close scenarios yet
    let dummy_script = "0020e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        .parse()
        .expect("static dummy script to always parse");
    let dummy_cltv_expiry = 40;

    tracing::info!("Adding custom output");
    let custom_output_details = channel_manager
        .add_custom_output(
            short_channel_id,
            maker_pk,
            margin_taker,
            margin_maker,
            dummy_cltv_expiry,
            dummy_script,
        )
        .map_err(|e| anyhow!(e))?;
    tracing::info!(?custom_output_details, "Added custom output");

    let custom_output_id = base64::encode(custom_output_details.id.0);

    let mut conn = db::acquire().await?;

    dal::insert_cfd(
        margin_taker as i64,
        custom_output_id,
        liquidation_price,
        expiry,
        order,
        &mut conn,
    )
    .await?;

    Ok(())
}
