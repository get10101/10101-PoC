use crate::bitmex::Quote;
use anyhow::Result;
use bdk::bitcoin::hashes::hex::ToHex;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::Address;
use bdk::bitcoin::Txid;
use http_api_problem::HttpApiProblem;
use http_api_problem::StatusCode;
use rocket::serde::json::Json;
use rocket::serde::Deserialize;
use rocket::serde::Serialize;
use rocket::State;
use rust_decimal::Decimal;
use std::str::FromStr;
use ten_ten_one::config::maker_peer_info;
use ten_ten_one::lightning::NodeInfo;
use ten_ten_one::lightning::PeerInfo;
use ten_ten_one::wallet;
use ten_ten_one::wallet::close_channel;
use ten_ten_one::wallet::create_invoice;
use ten_ten_one::wallet::get_address;
use ten_ten_one::wallet::get_balance;
use ten_ten_one::wallet::get_channel_manager;
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

#[rocket::get("/faucet/<address>")]
pub async fn get_faucet(address: String) -> Result<Json<Txid>, HttpApiProblem> {
    let address = Address::from_str(address.as_str()).map_err(|e| {
        HttpApiProblem::new(StatusCode::BAD_REQUEST)
            .title("Invalid address")
            .detail(format!("Provided address {address} was not valid: {e:#}"))
    })?;

    let txid = send_to_address(address, 10_000).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to fund address")
            .detail(format!("{e:#}"))
    })?;

    Ok(Json(txid))
}

#[rocket::get("/offer")]
pub async fn get_offer(
    rx_quote_receiver: &State<watch::Receiver<Option<Quote>>>,
    spread_receiver: &State<watch::Receiver<SpreadPrice>>,
) -> Result<Json<Offer>, HttpApiProblem> {
    let rx_quote_receiver = rx_quote_receiver.inner().clone();
    let quote = *rx_quote_receiver.borrow();

    let spread = spread_receiver.inner().clone().borrow().load();
    let spread = Decimal::try_from(spread).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to parse spread")
            .detail(format!("Failed to parse spread from state: {e:#}"))
    })?;

    match quote {
        Some(quote) => Ok(Json(Offer {
            bid: (quote.bid * (Decimal::ONE - spread)),
            ask: (quote.ask * (Decimal::ONE + spread)),
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

/// Spread applied
#[derive(Clone, Copy)]
pub struct SpreadPrice(f32);

impl SpreadPrice {
    /// For ease of PUT request, we expect spread multiplied by 1000
    pub fn new(spread: i32) -> SpreadPrice {
        SpreadPrice(spread as f32 / 1000.0)
    }
    pub fn load(&self) -> f32 {
        self.0
    }
}

// TODO: changing the spread via an api has been added for demo purposes, remove when not needed
// anymore
#[rocket::put("/spread/<spread>")]
pub async fn put_spread(
    spread_sender: &State<watch::Sender<SpreadPrice>>,
    spread: i32,
) -> Result<(), HttpApiProblem> {
    spread_sender
        .inner()
        .send(SpreadPrice::new(spread))
        .map_err(|_| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR).title("cannot set the spread")
        })?;
    Ok(())
}

#[rocket::get("/spread")]
pub async fn get_spread(
    spread_receiver: &State<watch::Receiver<SpreadPrice>>,
) -> Result<Json<f32>, HttpApiProblem> {
    let spread = spread_receiver.inner().clone().borrow().load();
    Ok(Json(spread))
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

    let node_info = wallet::get_node_info().map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed get new address")
            .detail(format!("Internal wallet error: {e:#}"))
    })?;
    Ok(Json(WalletDetails {
        address,
        balance,
        node_id: node_info.node_id,
    }))
}

#[rocket::get("/alive")]
pub async fn alive() -> Result<Json<PeerInfo>, HttpApiProblem> {
    Ok(Json(maker_peer_info()))
}

#[rocket::post("/channel/close/<remote_node_id>?<force>")]
pub async fn post_close_channel(
    remote_node_id: String,
    force: Option<bool>,
) -> Result<(), HttpApiProblem> {
    let force = force.unwrap_or_default();

    let remote_node_id = remote_node_id.parse().map_err(|e| {
        HttpApiProblem::new(StatusCode::BAD_REQUEST)
            .title("Failed to force-close channel")
            .detail(format!("Could not parse remote node ID: {e:#}"))
    })?;

    close_channel(remote_node_id, force).await.map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to close channel")
            .detail(format!("{e:#}"))
    })?;

    Ok(())
}

#[rocket::post("/channel/open", data = "<request>", format = "json")]
pub async fn post_open_channel(
    request: Json<OpenChannelRequest>,
) -> Result<Json<OpenChannelResponse>, HttpApiProblem> {
    let funding_txid = send_to_address(request.address_to_fund.clone(), request.fund_amount + 500)
        .map_err(|e| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
                .title("Failed to open channel with maker")
                .detail(format!("Failed to transfer funds: {e:#}"))
        })?;

    Ok(Json(OpenChannelResponse { funding_txid }))
}

#[rocket::post("/send/<address>/<amount>")]
pub async fn post_send_to_address(address: String, amount: u64) -> Result<String, HttpApiProblem> {
    let address = address.parse().map_err(|_| {
        HttpApiProblem::new(StatusCode::BAD_REQUEST)
            .title("Failed to send bitcoin to address")
            .detail("Invalid address")
    })?;

    let txid = send_to_address(address, amount).map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to send bitcoin to address")
            .detail(format!("{e:#}"))
    })?;

    Ok(txid.to_string())
}

#[rocket::post("/invoice/send/<invoice>")]
pub async fn post_pay_invoice(invoice: String) -> Result<(), HttpApiProblem> {
    send_lightning_payment(&invoice).await.map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to pay lightning invoice")
            .detail(format!("{e:#}"))
    })
}

#[rocket::get("/invoice/create")]
pub async fn get_new_invoice() -> Result<String, HttpApiProblem> {
    // FIXME: Hard-code the parameters for testing
    create_invoice(10000, 6000, "maker's invoice".to_string())
        .await
        .map_err(|e| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
                .title("Failed to create lightning invoice")
                .detail(format!("{e:#}"))
        })
}

#[derive(Serialize)]
pub struct ChannelDetail {
    pub channel_id: String,
    pub counterparty: String,
    pub funding_txo: Option<String>,
    pub channel_type: Option<String>,
    pub channel_value_satoshis: u64,
    pub unspendable_punishment_reserve: Option<u64>,
    pub user_channel_id: u64,
    pub balance_msat: u64,
    pub outbound_capacity_msat: u64,
    pub next_outbound_htlc_limit_msat: u64,
    pub inbound_capacity_msat: u64,
    pub confirmations_required: Option<u32>,
    pub force_close_spend_delay: Option<u16>,
    pub is_outbound: bool,
    pub is_channel_ready: bool,
    pub is_usable: bool,
    pub is_public: bool,
    pub inbound_htlc_minimum_msat: Option<u64>,
    pub inbound_htlc_maximum_msat: Option<u64>,
    pub config: Option<ChannelConfig>,
}
#[derive(Serialize)]
pub struct ChannelConfig {
    pub forwarding_fee_proportional_millionths: u32,
    pub forwarding_fee_base_msat: u32,
    pub cltv_expiry_delta: u16,
    pub max_dust_htlc_exposure_msat: u64,
    pub force_close_avoidance_max_fee_satoshis: u64,
}

#[rocket::get("/channel/list")]
pub async fn get_channel_details() -> Result<Json<Vec<ChannelDetail>>, HttpApiProblem> {
    let list = get_channel_manager()
        .map_err(|e| {
            HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
                .title("Failed to create lightning invoice")
                .detail(format!("{e:#}"))
        })?
        .list_channels();

    let vec = list
        .iter()
        .map(|cd| ChannelDetail {
            channel_id: hex::encode(cd.channel_id),
            counterparty: cd.counterparty.node_id.to_hex(),
            funding_txo: cd
                .funding_txo
                .map(|ft| format!("{}{}", ft.txid.to_hex(), ft.index)),
            channel_type: cd.channel_type.clone().map(|ct| ct.to_string()),
            channel_value_satoshis: cd.channel_value_satoshis,
            unspendable_punishment_reserve: cd.unspendable_punishment_reserve,
            user_channel_id: cd.user_channel_id,
            balance_msat: cd.balance_msat,
            outbound_capacity_msat: cd.outbound_capacity_msat,
            next_outbound_htlc_limit_msat: cd.next_outbound_htlc_limit_msat,
            inbound_capacity_msat: cd.inbound_capacity_msat,
            confirmations_required: cd.confirmations_required,
            force_close_spend_delay: cd.force_close_spend_delay,
            is_outbound: cd.is_outbound,
            is_channel_ready: cd.is_channel_ready,
            is_usable: cd.is_usable,
            is_public: cd.is_public,
            inbound_htlc_minimum_msat: cd.inbound_htlc_minimum_msat,
            inbound_htlc_maximum_msat: cd.inbound_htlc_maximum_msat,
            config: cd.config.map(|c| ChannelConfig {
                forwarding_fee_proportional_millionths: c.forwarding_fee_proportional_millionths,
                forwarding_fee_base_msat: c.forwarding_fee_base_msat,
                cltv_expiry_delta: c.cltv_expiry_delta,
                max_dust_htlc_exposure_msat: c.max_dust_htlc_exposure_msat,
                force_close_avoidance_max_fee_satoshis: c.force_close_avoidance_max_fee_satoshis,
            }),
        })
        .collect::<Vec<_>>();

    tracing::info!(?list, "Open channels: {}", list.len());
    Ok(Json(vec))
}

#[rocket::get("/node/info")]
pub async fn get_node_info() -> Result<Json<NodeInfo>, HttpApiProblem> {
    let info = wallet::get_node_info().map_err(|e| {
        HttpApiProblem::new(StatusCode::INTERNAL_SERVER_ERROR)
            .title("Failed to retrieve node info")
            .detail(format!("{e:#}"))
    })?;
    Ok(Json(info))
}
