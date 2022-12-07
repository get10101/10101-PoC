use crate::wallet;
use crate::wallet::is_first_channel_usable;
use tokio::task::JoinHandle;

pub async fn spawn() -> JoinHandle<()> {
    // keep connection with maker alive!
    tokio::spawn(async {
        let mut connected = false;
        loop {
            if !connected || !is_first_channel_usable() {
                connected = connect().await;
            }

            // looping here indefinitely to keep the connection with the maker alive.
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    })
}

async fn connect() -> bool {
    let result = wallet::connect().await;
    match result {
        Ok(()) => {
            tracing::info!("Successfully connected to maker");
            true
        }
        Err(err) => {
            tracing::warn!("Failed to connect to maker! {err:?}");
            false
        }
    }
}
