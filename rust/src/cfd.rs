use crate::db;
use crate::wallet;
use crate::wallet::maker_pk;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum ContractSymbol {
    BtcUsd,
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
    pub leverage: i64,
    #[frb(non_final)]
    pub quantity: i64,
    #[frb(non_final)]
    pub contract_symbol: ContractSymbol,
    #[frb(non_final)]
    pub position: Position,
    #[frb(non_final)]
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
    pub margin: f64,
}

pub async fn open(order: &Order) -> Result<()> {
    let liquidation_price: f64 = order.calculate_liquidation_price().0;
    let expiry = order.calculate_expiry().0;

    if order.leverage > 2 {
        bail!("Only leverage x1 and x2 are supported at the moment");
    }

    let maker_amount = order.quantity.saturating_mul(order.leverage);

    tracing::info!(
        "Opening CFD with taker amount {} maker amount {maker_amount}",
        order.quantity
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
        .context("Could not retrieve short channel id")?;

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

    let margin = order.margin_taker().0;

    let mut connection = db::acquire().await?;

    let created = time::OffsetDateTime::now_utc().unix_timestamp();
    let updated = time::OffsetDateTime::now_utc().unix_timestamp();

    let query_result = sqlx::query!(
        r#"
        INSERT INTO cfd (custom_output_id, contract_symbol, position, leverage, created, updated, state_id, quantity, expiry, open_price, liquidation_price, margin)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        "#,
        custom_output_id,
        order.contract_symbol,
        order.position,
        order.leverage,
        created,
        updated,
        1,
        order.quantity,
        expiry,
        order.open_price,
        liquidation_price,
        margin
    ).execute(&mut connection).await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert cfd");
    }

    tracing::info!("Successfully stored CFD to database");

    Ok(())
}

pub async fn settle(taker_amount: u64, maker_amount: u64) -> Result<()> {
    tracing::info!("Settling CFD with taker amount {taker_amount} and maker amount {maker_amount}");

    let channel_manager = wallet::get_channel_manager()?;

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
