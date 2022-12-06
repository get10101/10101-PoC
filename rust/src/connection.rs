use crate::wallet;
use anyhow::Result;

pub async fn connect() -> Result<bool> {
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
