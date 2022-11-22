use crate::db;
use crate::offer::Offer;
use crate::wallet;
use crate::wallet::maker_pk;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use flutter_rust_bridge::frb;
use lightning::ln::channelmanager::CustomOutputId;
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
    pub close_price: Option<f64>,
    pub liquidation_price: f64,
    pub margin: f64,
}

impl Cfd {
    pub fn derive_order(&self) -> Order {
        Order {
            leverage: self.leverage,
            quantity: self.quantity,
            contract_symbol: self.contract_symbol,
            position: self.position,
            open_price: self.open_price,
        }
    }
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

fn taker_payout_sats(cfd: &Cfd, closing_price: f64) -> Result<Decimal> {
    // TODO: need to derive an order from the cfd as dependent functions are only available on the
    // order eventually the order should probably be included in the cfd.
    let order = cfd.derive_order();

    let taker_payout_btc = order.calculate_payout_at_price(closing_price)?;
    let taker_payout_sats =
        Decimal::try_from(taker_payout_btc * 100_000_000.0).expect("payout to fit in Decimal");
    let taker_payout_sats = taker_payout_sats
        .round_dp_with_strategy(0, rust_decimal::RoundingStrategy::MidpointAwayFromZero);

    Ok(taker_payout_sats)
}

pub async fn settle(cfd: &Cfd, offer: &Offer) -> Result<()> {
    let closing_price = match cfd.position {
        Position::Long => offer.bid,
        Position::Short => offer.ask,
    };

    let taker_payout_sats = taker_payout_sats(cfd, closing_price)?;

    tracing::info!(
        %taker_payout_sats, "Settling CFD"
    );

    let taker_payout_msats = taker_payout_sats * Decimal::from(1000);
    let taker_payout_msats = taker_payout_msats
        .to_u64()
        .expect("decimal to fit into u64");

    let channel_manager = wallet::get_channel_manager()?;

    let custom_output_id = base64::decode(&cfd.custom_output_id)?;
    let custom_output_id: [u8; 32] = custom_output_id
        .try_into()
        .expect("custom output ID to be 32 bytes long");

    let custom_output_id = CustomOutputId(custom_output_id);

    channel_manager
        .remove_custom_output(custom_output_id, taker_payout_msats)
        .map_err(|e| anyhow!("Failed to settle CFD: {e:?}"))?;

    // TODO: We shouldn't just assume that removing the custom output
    // has succeeded as soon as the previous call returns `Ok`. The
    // rest of the protocol might still fail! That mean that we should
    // be waiting for a particular event to be emitted by the LDK
    // before we persist this information

    let mut connection = db::acquire().await?;

    let updated = time::OffsetDateTime::now_utc().unix_timestamp();
    let query_result = sqlx::query!(
        r#"
        UPDATE cfd
        SET
            state_id = $1, updated = $2, close_price = $3
        WHERE
            cfd.custom_output_id = $4
        "#,
        2,
        updated,
        closing_price,
        cfd.custom_output_id,
    )
    .execute(&mut connection)
    .await?;

    if query_result.rows_affected() != 1 {
        bail!(
            "Failed to mark CFD as settled in DB. Custom output ID: {}",
            cfd.custom_output_id
        );
    }

    tracing::info!("CFD settled");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_settlement() {
        let cfd = &Cfd {
            id: 0,
            custom_output_id: "".to_owned(),
            contract_symbol: ContractSymbol::BtcUsd,
            position: Position::Long,
            leverage: 2,
            updated: 0,
            created: 0,
            state: CfdState::Open,
            quantity: 100,
            expiry: 1000,
            open_price: 15_587.625,
            close_price: None,
            liquidation_price: 10_000.0,
            margin: 0.00319536,
        };

        let closing_price = 16_078.615;

        let payout = taker_payout_sats(cfd, closing_price).unwrap();

        dbg!(payout);
    }
}
