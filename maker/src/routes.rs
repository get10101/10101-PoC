use crate::bitmex::Quote;
use anyhow::Result;
use http_api_problem::HttpApiProblem;
use http_api_problem::StatusCode;
use rocket::serde::json::Json;
use rocket::serde::Deserialize;
use rocket::serde::Serialize;
use rocket::State;
use rust_decimal::Decimal;
use rust_decimal_macros::dec;
use ten_ten_one::wallet::force_close_channel;
use tokio::sync::watch;

#[derive(Serialize, Deserialize, Debug)]
pub struct Offer {
    #[serde(with = "rust_decimal::serde::float")]
    bid: Decimal,
    #[serde(with = "rust_decimal::serde::float")]
    ask: Decimal,
    #[serde(with = "rust_decimal::serde::float")]
    index: Decimal,
}

#[rocket::get("/offer")]
pub async fn get_offer(
    rx_quote_receiver: &State<watch::Receiver<Option<Quote>>>,
) -> Result<Json<Offer>, HttpApiProblem> {
    let rx_quote_receiver = rx_quote_receiver.inner().clone();
    let quote = *rx_quote_receiver.borrow();

    // TODO: take spread from clap
    let spread = dec!(0.015);

    match quote {
        Some(quote) => Ok(Json(Offer {
            bid: (quote.ask * (Decimal::ONE + spread)),
            ask: (quote.bid * (Decimal::ONE - spread)),
            index: quote.index,
        })),
        None => Err("No quotes found"),
    }
    .map_err(|e| {
        HttpApiProblem::new(StatusCode::NOT_FOUND)
            .title("No quotes found")
            .detail(e.to_string())
    })
}

#[rocket::post("/channel/<remote_node_id>")]
pub async fn post_force_close_channel(remote_node_id: String) -> Result<(), HttpApiProblem> {
    let remote_node_id = remote_node_id.parse().map_err(|e| {
        HttpApiProblem::new(StatusCode::BAD_REQUEST)
            .title("Failed to force-close channel")
            .detail(format!("Could not parse remote node ID: {e:#}"))
    })?;

    force_close_channel(remote_node_id).await.map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to force-close channel")
            .detail(format!("{e:#}"))
    })?;

    Ok(())
}
