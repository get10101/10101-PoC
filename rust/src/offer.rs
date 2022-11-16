use anyhow::anyhow;
use anyhow::Result;

use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug)]
pub struct Offer {
    pub bid: f64,
    pub ask: f64,
    pub index: f64,
}

pub async fn get_offer(endpoint: &str) -> Result<Offer> {
    reqwest::get(format!("{}/api/offer", endpoint))
        .await?
        .json::<Offer>()
        .await
        .map_err(|e| anyhow!("Failed to fetch offer {e:?}"))
}
