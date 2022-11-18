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

pub async fn get_offer() -> Result<Offer> {
    let client = reqwest::Client::builder()
        .timeout(crate::wallet::TCP_TIMEOUT)
        .build()?;
    client
        .get(format!("{}/api/offer", crate::wallet::MAKER_ENDPOINT))
        .send()
        .await?
        .json::<Offer>()
        .await
        .map_err(|e| anyhow!("Failed to fetch offer {e:?}"))
}
