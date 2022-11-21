use anyhow::anyhow;
use anyhow::Result;
use serde::Deserialize;
use serde::Serialize;

use crate::wallet::maker_endpoint;

#[derive(Serialize, Deserialize, Debug)]
pub struct Offer {
    pub bid: f64,
    pub ask: f64,
    pub index: f64,
}

pub async fn get_offer() -> Result<Option<Offer>> {
    let client = reqwest::Client::builder()
        .timeout(crate::wallet::TCP_TIMEOUT)
        .build()?;
    let result = client.get(maker_endpoint() + "/api/offer").send().await;
    let response = match result {
        Ok(res) => res,
        Err(err) => {
            tracing::error!("Could not fetch offers {err:?}");
            return Ok(None);
        }
    };
    let result = response
        .json::<Offer>()
        .await
        .map_err(|e| anyhow!("Failed to fetch offer {e:?}"))?;
    Ok(Some(result))
}
