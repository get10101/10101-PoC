use crate::config;
use crate::wallet;
use anyhow::Result;

/// blocks the current thread, if you want this to be run asynchronously you need to spawn a thread
/// from the outside.
pub async fn keep_alive() -> Result<()> {
    let mut connected = false;
    loop {
        let alive = check_alive().await?;

        if !connected || !alive {
            connected = connect().await?;
        }

        // looping here indefinitely to keep the connection with the maker alive.
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
}

async fn check_alive() -> Result<bool> {
    tracing::trace!("Checking if maker is alive");
    let client = reqwest::Client::builder()
        .timeout(config::TCP_TIMEOUT)
        .build()?;
    let result = client
        .get(config::maker_endpoint() + "/api/alive")
        .send()
        .await;

    let alive = match result {
        Ok(_) => true,
        Err(err) => {
            tracing::warn!("Maker is offline! {err:?}");
            false
        }
    };

    Ok(alive)
}

async fn connect() -> Result<bool> {
    let result = wallet::connect().await;
    let connected = match result {
        Ok(()) => {
            tracing::info!("Successfully connected to maker");
            true
        }
        Err(err) => {
            tracing::warn!("Failed to connect to maker! {err:?}");
            false
        }
    };

    Ok(connected)
}
