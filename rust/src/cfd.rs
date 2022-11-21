use crate::db;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::maker_pk;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;

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

    let margin_taker_as_btc = order.margin_taker().0;
    // Convert to msats
    let margin_taker = (margin_taker_as_btc * 100_000_000.0 * 1000.0) as u64;
    // TODO: is this correct? why do we multiply the leverage for the maker margin?
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
        .context("Could not retrieve short channel id")?;

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

    let mut connection = db::acquire().await?;

    let created = time::OffsetDateTime::now_utc().unix_timestamp();
    let updated = time::OffsetDateTime::now_utc().unix_timestamp();
    let margin_taker = margin_taker as i64;
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
        margin_taker
    ).execute(&mut connection).await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert cfd");
    }

    tracing::info!("Successfully stored CFD to database");

    Ok(())
}

pub async fn settle(order: Order, offer: Offer) -> Result<()> {
    // TODO: this method should not expect the order, but rather the CFD, expecting the order model
    // here since depending functions are on the order. Note, eventually the order model should
    // probably be part of the cfd model.
    let total_margin_sats = Decimal::try_from(order.margin_total().0)? * Decimal::from(100_000_000);
    let taker_margin_sats = Decimal::try_from(order.margin_taker().0)? * Decimal::from(100_000_000);

    let price = match order.position {
        Position::Long => offer.bid,
        Position::Short => offer.ask,
    };

    let taker_pnl_btc = Decimal::try_from(order.calculate_profit_taker(price)?.0)?;
    let taker_pnl_sats = taker_pnl_btc * Decimal::from(100_000_000);

    // the taker's losses are capped by the margin they put up when opening the CFD
    let taker_payout_sats = (taker_margin_sats + taker_pnl_sats).max(Decimal::ZERO);
    let taker_payout_sats = taker_payout_sats
        .round_dp_with_strategy(0, rust_decimal::RoundingStrategy::MidpointAwayFromZero);

    let maker_payout_sats = total_margin_sats - taker_payout_sats;

    tracing::info!(
        %taker_payout_sats, %maker_payout_sats, "Settling CFD"
    );

    let channel_manager = wallet::get_channel_manager()?;

    let custom_output_id = *channel_manager
        .custom_outputs()
        .first()
        .context("No custom outputs in channel")?;

    let custom_output_id = CustomOutputId(custom_output_id);

    let taker_payout_msats = taker_payout_sats * Decimal::from(1000);
    let taker_payout_msats = taker_payout_msats
        .to_u64()
        .expect("decimal to fit into u64");

    let maker_payout_msats = maker_payout_sats * Decimal::from(1000);
    let maker_payout_msats = maker_payout_msats
        .to_u64()
        .expect("decimal to fit into u64");

    channel_manager
        .remove_custom_output(custom_output_id, taker_payout_msats, maker_payout_msats)
        .map_err(|e| anyhow!("Failed to settle CFD: {e:?}"))?;

    Ok(())
}
