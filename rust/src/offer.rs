use crate::config::maker_endpoint;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Result;
use reqwest::StatusCode;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Offer {
    pub bid: f64,
    pub ask: f64,
    pub index: f64,
}

pub async fn get_offer() -> Result<Offer> {
    let client = reqwest::Client::builder()
        .timeout(crate::config::TCP_TIMEOUT)
        .build()?;
    let response = client.get(maker_endpoint() + "/api/offer").send().await?;

    if response.status() == StatusCode::NOT_FOUND
        || response.status() == StatusCode::INTERNAL_SERVER_ERROR
    {
        let response = response.text().await?;
        tracing::debug!("Failed to fetch offer: {response}");
        bail!("Failed to fetch offer: {response}");
    }

    response.json::<Offer>().await.map_err(|e| anyhow!(e))
}
