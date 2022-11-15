use http_api_problem::HttpApiProblem;
use http_api_problem::StatusCode;
use rocket::serde::json::Json;
use rocket::serde::Deserialize;
use rocket::serde::Serialize;
use ten_ten_one::wallet::force_close_channel;

#[derive(Serialize, Deserialize, Debug)]
pub struct Price(u64);

impl From<u64> for Price {
    fn from(val: u64) -> Self {
        Self(val)
    }
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Offer {
    bid: Price,
    ask: Price,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Offers {
    long: Offer,
    short: Offer,
    index_price: Price,
}

#[rocket::get("/offers")]
pub async fn get_offers() -> Result<Json<Offers>, HttpApiProblem> {
    // TODO: Use real values instead of hard-coding

    let long = Offer {
        bid: 19000.into(),
        ask: 21000.into(),
    };

    // Different values only to ensure we're fetching the correct ones
    let short = Offer {
        bid: 20500.into(),
        ask: 19500.into(),
    };

    let index_price = 19750.into();

    let offers = Offers {
        long,
        short,
        index_price,
    };

    Ok(Json(offers))
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
