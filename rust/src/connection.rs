use crate::wallet;
use crate::wallet::is_first_channel_usable;
use anyhow::Result;

/// blocks the current thread, if you want this to be run asynchronously you need to spawn a thread
/// from the outside.
pub async fn keep_alive() -> Result<()> {
    let mut connected = false;
    loop {
        if !connected || !is_first_channel_usable() {
            connected = connect().await?;
        }

        // looping here indefinitely to keep the connection with the maker alive.
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
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
