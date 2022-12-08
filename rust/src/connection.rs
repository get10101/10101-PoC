use crate::config;
use crate::lightning::PeerManager;
use bdk::bitcoin::secp256k1::PublicKey;
use std::sync::Arc;
use std::time::Duration;
use tokio::task::JoinHandle;

pub fn spawn(peer_manager: Arc<PeerManager>) -> JoinHandle<()> {
    // keep connection with maker alive!
    tokio::spawn(async move {
        let peer_info = config::maker_peer_info();
        loop {
            tracing::info!("Connecting to {peer_info}");
            match lightning_net_tokio::connect_outbound(
                Arc::clone(&peer_manager),
                peer_info.pubkey,
                peer_info.peer_addr,
            )
            .await
            {
                Some(connection_closed_future) => {
                    let mut connection_closed_future = Box::pin(connection_closed_future);
                    while !is_connected(&peer_manager, peer_info.pubkey) {
                        if futures::poll!(&mut connection_closed_future).is_ready() {
                            tracing::warn!("Peer disconnected before we finished the handshake! Retrying in 5 seconds.");
                            tokio::time::sleep(Duration::from_secs(5)).await;
                            return;
                        }
                        tokio::time::sleep(Duration::from_secs(5)).await;
                    }
                    tracing::info!("Successfully connected to {peer_info}");
                    connection_closed_future.await;
                    tracing::warn!("Lost connection to maker, retrying immediately.")
                }
                None => {
                    tracing::warn!("Failed to connect to maker! Retrying in 5 seconds.");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    })
}

fn is_connected(peer_manager: &Arc<PeerManager>, pubkey: PublicKey) -> bool {
    peer_manager
        .get_peer_node_ids()
        .iter()
        .any(|id| *id == pubkey)
}
