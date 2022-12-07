use crate::config;
use crate::lightning::PeerManager;
use crate::wallet::is_first_channel_usable;
use std::sync::Arc;
use std::time::Duration;
use tokio::task::JoinHandle;

pub struct Connection {
    peer_manager: Arc<PeerManager>,
}

pub async fn spawn(peer_manager: Arc<PeerManager>) -> JoinHandle<()> {
    let connection = Connection { peer_manager };

    // keep connection with maker alive!
    tokio::spawn(async move {
        let mut connected = false;
        loop {
            if !connected || !is_first_channel_usable() {
                connected = connection.connect().await;
            }

            // looping here indefinitely to keep the connection with the maker alive.
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    })
}

impl Connection {
    async fn connect(&self) -> bool {
        let peer_info = config::maker_peer_info();
        for node_pubkey in self.peer_manager.get_peer_node_ids() {
            if node_pubkey == peer_info.pubkey {
                tracing::trace!("Already connected to maker {peer_info}.");
                return true;
            }
        }

        tracing::debug!("Connecting to {peer_info}");

        match lightning_net_tokio::connect_outbound(
            Arc::clone(&self.peer_manager),
            peer_info.pubkey,
            peer_info.peer_addr,
        )
        .await
        {
            Some(connection_closed_future) => {
                let mut connection_closed_future = Box::pin(connection_closed_future);
                loop {
                    match futures::poll!(&mut connection_closed_future) {
                        std::task::Poll::Ready(_) => {
                            tracing::warn!("Peer disconnected before we finished the handshake!");
                            return false;
                        }
                        std::task::Poll::Pending => {}
                    }
                    // Avoid blocking the tokio context by sleeping a bit
                    match self
                        .peer_manager
                        .get_peer_node_ids()
                        .iter()
                        .find(|id| **id == peer_info.pubkey)
                    {
                        Some(_) => {
                            tracing::info!("Successfully connected to maker {peer_info}");
                            return true;
                        }
                        None => tokio::time::sleep(Duration::from_millis(10)).await,
                    }
                }
            }
            None => {
                tracing::warn!("Failed to connect to maker!");
                false
            }
        }
    }
}
