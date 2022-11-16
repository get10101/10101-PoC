use anyhow::anyhow;
use anyhow::Result;

use serde::Deserialize;
use serde::Serialize;

static MAKER_ENDPOINT: &str = "http://127.0.0.1:8000";

#[derive(Serialize, Deserialize, Debug)]
pub struct Offer {
    pub bid: f64,
    pub ask: f64,
    pub index: f64,
}

pub async fn get_offer() -> Result<Offer> {
    reqwest::get(format!("{}/api/offer", MAKER_ENDPOINT))
        .await?
        .json::<Offer>()
        .await
        .map_err(|e| anyhow!("Failed to fetch offer {e:?}"))
}
