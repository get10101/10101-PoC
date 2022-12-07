use crate::api::Event;
use crate::config::maker_endpoint;
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
            let offer = get_offer().await;
            stream.add(Event::Offer(offer));
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    })
}

pub async fn get_offer() -> Option<Offer> {
    let client = reqwest::Client::builder()
        .timeout(crate::config::TCP_TIMEOUT)
        .build()
        .expect("reqwest client to build");
    let result = client.get(maker_endpoint() + "/api/offer").send().await;
    let response = match result {
        Ok(res) => res,
        Err(err) => {
            tracing::error!("Could not fetch offers {err:?}");
            return None;
        }
    };

    if response.status() == StatusCode::NOT_FOUND
        || response.status() == StatusCode::INTERNAL_SERVER_ERROR
    {
        tracing::warn!("Failed to fetch offer");
        return None;
    }

    match response.json::<Offer>().await {
        Ok(offer) => Some(offer),
        Err(err) => {
            tracing::error!("Could not fetch offers {err:?}");
            None
        }
    }
}
