use crate::api::Event;
use crate::config::maker_endpoint;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Result;
use flutter_rust_bridge::StreamSink;
use reqwest::StatusCode;
use serde::Deserialize;
use serde::Serialize;
use tokio::task::JoinHandle;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Offer {
    pub bid: f64,
    pub ask: f64,
    pub index: f64,
}

pub async fn spawn(stream: StreamSink<Event>) -> JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            let offer = get_offer().await.ok();
            stream.add(Event::Offer(offer));
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    })
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
