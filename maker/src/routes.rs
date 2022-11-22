use crate::bitmex::Quote;
use anyhow::Result;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::Address;
use http_api_problem::HttpApiProblem;
use http_api_problem::StatusCode;
use rocket::serde::json::Json;
use rocket::serde::Deserialize;
use rocket::serde::Serialize;
use rocket::State;
use rust_decimal::Decimal;
use std::sync::atomic::AtomicI32;
use std::sync::atomic::Ordering;
use ten_ten_one::wallet::create_invoice;
use ten_ten_one::wallet::force_close_channel;
use ten_ten_one::wallet::get_address;
use ten_ten_one::wallet::get_balance;
use ten_ten_one::wallet::get_channel_manager;
use ten_ten_one::wallet::get_node_id;
use ten_ten_one::wallet::send_lightning_payment;
use ten_ten_one::wallet::send_to_address;
use ten_ten_one::wallet::Balance;
use ten_ten_one::wallet::OpenChannelRequest;
use ten_ten_one::wallet::OpenChannelResponse;
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
    spread_state: &State<SpreadPrice>,
) -> Result<Json<Offer>, HttpApiProblem> {
    let rx_quote_receiver = rx_quote_receiver.inner().clone();
    let quote = *rx_quote_receiver.borrow();

    let spread: f32 = spread_state.inner().load();
    let spread = Decimal::try_from(spread).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to parse spread")
            .detail(format!("Failed to parse spread from state: {e:#}"))
    })?;

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
// TODO: changing the spread via an api has been added for demo purposes, remove when not needed
// anymore
pub struct SpreadPrice(AtomicI32);

impl SpreadPrice {
    pub fn new(spread: i32) -> SpreadPrice {
        SpreadPrice(AtomicI32::new(spread))
    }
    pub fn load(&self) -> f32 {
        let spread = self.0.load(Ordering::Relaxed);
        (spread as f32) / 1000.0
    }
    pub fn store(&self, spread: i32) {
        self.0.store(spread, Ordering::Relaxed);
    }
}

#[rocket::put("/spread/<spread>")]
pub async fn put_spread(
    spread_state: &State<SpreadPrice>,
    spread: i32,
) -> Result<(), HttpApiProblem> {
    spread_state.inner().store(spread);
    Ok(())
}

#[rocket::get("/spread")]
pub async fn get_spread(spread_state: &State<SpreadPrice>) -> Result<Json<f32>, HttpApiProblem> {
    Ok(Json(spread_state.inner().load()))
}

#[derive(Serialize)]
pub struct WalletDetails {
    pub address: Address,
    pub balance: Balance,
    pub node_id: PublicKey,
}

#[allow(clippy::result_large_err)]
#[rocket::get("/wallet-details")]
pub fn get_wallet_details() -> Result<Json<WalletDetails>, HttpApiProblem> {
    let balance = get_balance().map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed get new balance")
            .detail(format!("Internal wallet error: {e:#}"))
    })?;

    let address = get_address().map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed get new address")
            .detail(format!("Internal wallet error: {e:#}"))
    })?;

    let node_id = get_node_id().map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed get new address")
            .detail(format!("Internal wallet error: {e:#}"))
    })?;
    Ok(Json(WalletDetails {
        address,
        balance,
        node_id,
    }))
}

#[rocket::post("/channel/close/<remote_node_id>")]
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

#[rocket::post("/channel/open", data = "<request>", format = "json")]
pub async fn post_open_channel(
    request: Json<OpenChannelRequest>,
) -> Result<Json<OpenChannelResponse>, HttpApiProblem> {
    let funding_txid = send_to_address(request.address_to_fund.clone(), request.fund_amount)
        .map_err(|e| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
                .title("Failed to open channel with maker")
                .detail(format!("Failed to transfer funds: {e:#}"))
        })?;

    Ok(Json(OpenChannelResponse { funding_txid }))
}

#[rocket::post("/invoice/send/<invoice>")]
pub async fn post_pay_invoice(invoice: String) -> Result<(), HttpApiProblem> {
    send_lightning_payment(&invoice).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to pay lightning invoice")
            .detail(format!("{e:#}"))
    })
}

#[rocket::get("/invoice/create")]
pub async fn get_new_invoice() -> Result<String, HttpApiProblem> {
    // FIXME: Hard-code the parameters for testing
    create_invoice(10000, 6000, "maker's invoice".to_string()).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to create lightning invoice")
            .detail(format!("{e:#}"))
    })
}

#[rocket::get("/channel/list")]
pub async fn get_channel_details() -> Result<(), HttpApiProblem> {
    let list = get_channel_manager()
        .map_err(|e| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
                .title("Failed to create lightning invoice")
                .detail(format!("{e:#}"))
        })?
        .list_channels();

    tracing::info!(?list, "Open channels: {}", list.len());
    Ok(())
}
