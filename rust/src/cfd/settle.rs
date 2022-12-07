use crate::cfd::dal;
use crate::cfd::models::Cfd;
use crate::cfd::models::Position;
use crate::db;
use crate::offer::Offer;
use crate::wallet;
use anyhow::anyhow;
use anyhow::Result;
use lightning::ln::channelmanager::CustomOutputId;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;

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

    let channel_manager = wallet::get_channel_manager().await?;

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
    dal::update_cfd(&cfd.custom_output_id, closing_price, &mut connection).await?;

    tracing::info!("CFD settled");

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cfd::models::CfdState;
    use crate::cfd::models::ContractSymbol;

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
