use crate::db;
use crate::wallet;
use crate::wallet::MAKER_IP;
use crate::wallet::MAKER_PK;
use crate::wallet::MAKER_PORT_HTTP;
use crate::wallet::MAKER_PORT_LIGHTNING;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum ContractSymbol {
    BtcUsd,
    EthUsd,
}

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum Position {
    Long,
    Short,
}

#[frb]
#[derive(Debug, Clone, Copy, sqlx::Type)]
pub struct Order {
    #[frb(non_final)]
    pub leverage: u8,
    #[frb(non_final)]
    pub quantity: u32,
    #[frb(non_final)]
    pub contract_symbol: ContractSymbol,
    #[frb(non_final)]
    pub position: Position,
    pub open_price: f64,
}

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum CfdState {
    Open,
    Closed,
    Failed,
}

pub struct Cfd {
    pub id: i64,
    pub custom_output_id: String,
    pub contract_symbol: ContractSymbol,
    pub position: Position,
    pub leverage: i64,
    pub updated: i64,
    pub created: i64,
    pub state: CfdState,
    pub quantity: i64,
    pub expiry: i64,
    pub open_price: f64,
    pub liquidation_price: f64,
}

pub async fn open(order: &Order) -> Result<()> {
    // TODO: calculate liquidation price
    let liquidation_price: f64 = 12314.23;
    // TODO: calculate expiry of cfd
    let expiry = time::OffsetDateTime::now_utc().unix_timestamp();

    if order.leverage > 2 {
        bail!("Only leverage x1 and x2 are supported at the moment");
    }

    let maker_amount = order.quantity.saturating_mul(order.leverage as u32);

    tracing::info!(
        "Opening CFD with taker amount {} maker amount {maker_amount}",
        order.quantity
    );

    let channel_manager = {
        let lightning = &wallet::get_wallet()?.lightning;
        lightning.channel_manager.clone()
    };

    let binding = channel_manager.list_channels();
    tracing::info!("Channels: {binding:?}");

    let channel_details = binding.first().context("No first channel found")?;
    let maker_pk = channel_details.counterparty.node_id;
    let short_channel_id = channel_details
        .short_channel_id
        .context("Could not retrieve short channel id")?;

    // TODO: Use  MAKER_PK meaningfully
    assert_eq!(maker_pk.to_string(), MAKER_PK, "Using wrong maker seed");
    let maker_connection_str = format!("{maker_pk}@{MAKER_IP}:{MAKER_PORT_LIGHTNING}");

    tracing::info!("Connection str: {maker_connection_str}");
    tracing::info!(
        "Maker http API: {}",
        format!("{MAKER_IP}:{MAKER_PORT_HTTP}")
    );

    // hardcoded because we are not dealing with force-close scenarios yet
    let dummy_script = "0020e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        .parse()
        .expect("static dummy script to always parse");
    let dummy_cltv_expiry = 40;

    // Convert to msats
    let taker_amount = order.quantity * 1000;
    let maker_amount = maker_amount * 1000;

    tracing::info!("Adding custom output");
    let custom_output_details = channel_manager
        .add_custom_output(
            short_channel_id,
            maker_pk,
            taker_amount as u64,
            maker_amount as u64,
            dummy_cltv_expiry,
            dummy_script,
        )
        .map_err(|e| anyhow!(e))?;
    tracing::info!(?custom_output_details, "Added custom output");

    let custom_output_id = base64::encode(custom_output_details.id.0);

    let mut connection = db::acquire().await?;

    let query_result = sqlx::query(
        r#"
        INSERT INTO cfd (custom_output_id, contract_symbol, position, leverage, created, updated, state_id, quantity, expiry, open_price, liquidation_price)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        "#,
    )
    .bind(custom_output_id)
    .bind(order.contract_symbol)
    .bind(order.position)
    .bind(order.leverage)
    .bind(time::OffsetDateTime::now_utc().unix_timestamp())
        .bind(time::OffsetDateTime::now_utc().unix_timestamp())
    .bind(1)
    .bind(order.quantity)
    .bind(expiry)
    .bind(order.open_price)
    .bind(liquidation_price).execute(&mut connection)
        .await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert cfd");
    }

    tracing::info!("Successfully stored CFD to database");

    Ok(())
}

pub async fn settle(taker_amount: u64, maker_amount: u64) -> Result<()> {
    tracing::info!("Settling CFD with taker amount {taker_amount} and maker amount {maker_amount}");

    let channel_manager = {
        let lightning = &wallet::get_wallet()?.lightning;
        lightning.channel_manager.clone()
    };

    let custom_output_id = *channel_manager
        .custom_outputs()
        .first()
        .context("No custom outputs in channel")?;

    let taker_amount_msats = taker_amount * 1000;
    let maker_amount_msats = maker_amount * 1000;

    channel_manager
        .remove_custom_output(custom_output_id, taker_amount_msats, maker_amount_msats)
        .map_err(|e| anyhow!("Failed to settle CFD: {e:?}"))?;

    Ok(())
}
