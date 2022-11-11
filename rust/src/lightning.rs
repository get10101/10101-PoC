use crate::disk;
use crate::disk::FilesystemLogger;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::bitcoin::blockdata::constants::genesis_block;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::BlockHash;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use futures::executor::block_on;
use lightning::chain;
use lightning::chain::chainmonitor;
use lightning::chain::channelmonitor::ChannelMonitor;
use lightning::chain::keysinterface::InMemorySigner;
use lightning::chain::keysinterface::KeysInterface;
use lightning::chain::keysinterface::KeysManager;
use lightning::chain::keysinterface::Recipient;
use lightning::chain::BestBlock;
use lightning::chain::ChannelMonitorUpdateStatus;
use lightning::chain::Confirm;
use lightning::chain::Filter;
use lightning::chain::Watch;
use lightning::ln::channelmanager;
use lightning::ln::channelmanager::ChainParameters;
use lightning::ln::channelmanager::ChannelManagerReadArgs;
use lightning::ln::channelmanager::SimpleArcChannelManager;
use lightning::ln::peer_handler::IgnoringMessageHandler;
use lightning::ln::peer_handler::MessageHandler;
use lightning::ln::peer_handler::SimpleArcPeerManager;
use lightning::onion_message::SimpleArcOnionMessenger;
use lightning::routing::gossip::NetworkGraph;
use lightning::routing::gossip::P2PGossipSync;
use lightning::routing::scoring::ProbabilisticScorer;
use lightning::util::config::UserConfig;
use lightning::util::events::Event;
use lightning::util::ser::ReadableArgs;
use lightning_background_processor::BackgroundProcessor;
use lightning_background_processor::GossipSync;
use lightning_invoice::payment;
use lightning_invoice::utils::DefaultRouter;
use lightning_net_tokio::SocketDescriptor;
use lightning_persister::FilesystemPersister;
use rand::thread_rng;
use rand::RngCore;
use std::fmt;
use std::iter;
use std::net::SocketAddr;
use std::path::Path;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::Duration;
use std::time::SystemTime;

/// Container to keep all the components of the lightning network in one place
pub struct LightningSystem {
    pub wallet: Arc<BdkLdkWallet>,
    pub chain_monitor: Arc<ChainMonitor>,
    pub channel_manager: Arc<ChannelManager>,
    pub peer_manager: Arc<PeerManager>,
    pub network_graph: Arc<NetGraph>,
    pub logger: Arc<FilesystemLogger>,
    pub keys_manager: Arc<KeysManager>,
    pub persister: Arc<FilesystemPersister>,
    pub gossip_sync: Arc<LdkGossipSync>,
}

pub struct PeerInfo {
    pub pubkey: PublicKey,
    pub peer_addr: SocketAddr,
}

impl ToString for PeerInfo {
    fn to_string(&self) -> String {
        format!("{}@{}", self.pubkey, self.peer_addr)
    }
}

impl LightningSystem {
    pub fn confirmables(&self) -> Vec<&dyn Confirm> {
        vec![
            &*self.channel_manager as &dyn chain::Confirm,
            &*self.chain_monitor as &dyn chain::Confirm,
        ]
    }
}

pub async fn open_channel(
    peer_manager: Arc<PeerManager>,
    channel_manager: Arc<ChannelManager>,
    peer_info: PeerInfo,
    channel_amount_sat: u64,
    data_dir: &Path,
) -> Result<()> {
    connect_peer_if_necessary(peer_info.pubkey, peer_info.peer_addr, peer_manager).await?;

    let _temp_channel_id = channel_manager
        .create_channel(peer_info.pubkey, channel_amount_sat, 0, 0, None)
        .map_err(|_| anyhow!("Could not create channel"))?;

    let path = data_dir.join("channel_peer_data");
    disk::persist_channel_peer(&path, &peer_info.to_string())
        .context("could not persist channel peer")?;

    tracing::info!("Channel has been successfully created");

    Ok(())
}

pub(crate) struct MillisatAmount(Option<u64>);

impl fmt::Display for MillisatAmount {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self.0 {
            Some(amt) => write!(f, "{}", amt),
            None => write!(f, "unknown"),
        }
    }
}

pub(crate) type BdkLdkWallet = bdk_ldk::LightningWallet<ElectrumBlockchain, MemoryDatabase>;

type LdkGossipSync =
    P2PGossipSync<Arc<NetGraph>, Arc<dyn chain::Access + Send + Sync>, Arc<FilesystemLogger>>;

type ChainMonitor = chainmonitor::ChainMonitor<
    InMemorySigner,
    Arc<dyn Filter + Send + Sync>,
    Arc<BdkLdkWallet>,
    Arc<BdkLdkWallet>,
    Arc<FilesystemLogger>,
    Arc<FilesystemPersister>,
>;

pub(crate) type PeerManager = SimpleArcPeerManager<
    SocketDescriptor,
    ChainMonitor,
    BdkLdkWallet,
    BdkLdkWallet,
    dyn chain::Access + Send + Sync,
    FilesystemLogger,
>;

pub(crate) type ChannelManager =
    SimpleArcChannelManager<ChainMonitor, BdkLdkWallet, BdkLdkWallet, FilesystemLogger>;

pub(crate) type InvoicePayer<E> =
    payment::InvoicePayer<Arc<ChannelManager>, Router, Arc<FilesystemLogger>, E>;

type Router = DefaultRouter<Arc<NetGraph>, Arc<FilesystemLogger>, Arc<Mutex<Scorer>>>;
type Scorer = ProbabilisticScorer<Arc<NetGraph>, Arc<FilesystemLogger>>;

pub(crate) type NetGraph = NetworkGraph<Arc<FilesystemLogger>>;

type ConfirmableMonitor = (
    ChannelMonitor<InMemorySigner>,
    Arc<BdkLdkWallet>,
    Arc<BdkLdkWallet>,
    Arc<FilesystemLogger>,
);

type OnionMessenger = SimpleArcOnionMessenger<FilesystemLogger>;

/// Set up lightning network system
///
/// Heavily based on the sample project, including comments
pub fn setup(
    lightning_wallet: BdkLdkWallet,
    network: bitcoin::Network,
    ldk_data_dir: &Path,
    seed: &[u8; 32],
) -> Result<LightningSystem> {
    let lightning_wallet = Arc::new(lightning_wallet);
    let ldk_data_dir = ldk_data_dir.to_string_lossy().to_string();

    // ## Setup
    // Step 1: Initialize the FeeEstimator

    // LightningWallet implements the FeeEstimator trait using the underlying bdk::Blockchain
    let fee_estimator = lightning_wallet.clone();

    // Step 2: Initialize the Logger
    let logger = Arc::new(FilesystemLogger::new(ldk_data_dir.clone()));

    // Step 3: Initialize the BroadcasterInterface

    // LightningWallet implements the BroadcasterInterface trait using the underlying
    // bdk::Blockchain
    let broadcaster = lightning_wallet.clone();

    // Step 4: Initialize Persist
    let persister = Arc::new(FilesystemPersister::new(ldk_data_dir.clone()));

    // TODO: Maybe we don't really need to have the transaction filter (this one
    // was removed in ldk-example)
    // Step 5: Initialize the Transaction Filter

    // LightningWallet implements the Filter trait for us
    let filter = lightning_wallet.clone();

    // Step 6: Initialize the ChainMonitor
    let chain_monitor: Arc<ChainMonitor> = Arc::new(chainmonitor::ChainMonitor::new(
        Some(filter.clone()),
        broadcaster.clone(),
        logger.clone(),
        fee_estimator.clone(),
        persister.clone(),
    ));

    let current_time = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .expect("to calculate duration");

    // Step 7: Initialize the KeysManager using our seed
    let keys_manager = Arc::new(KeysManager::new(
        seed,
        current_time.as_secs(),
        current_time.subsec_nanos(),
    ));

    // Step 8: Read ChannelMonitor state from disk
    let mut channelmonitors = persister
        .read_channelmonitors(keys_manager.clone())
        .unwrap();

    // TODO: This is new, check whether this is needed
    // Step 9: Poll for the best chain tip, which may be used by the channel manager & spv client
    // let polled_chain_tip = init::validate_best_block_header(lightning_wallet.as_ref())
    //     .await
    //     .expect("Failed to fetch best block header and best block");

    // Step 9: Initialize the ChannelManager
    let mut user_config = UserConfig::default();
    user_config
        .channel_handshake_limits
        .force_announced_channel_preference = false;

    let (_channel_manager_blockhash, channel_manager) = {
        if let Ok(mut f) = std::fs::File::open(format!("{ldk_data_dir}/manager")) {
            let mut channel_monitor_mut_references = Vec::new();
            for (_, channel_monitor) in channelmonitors.iter_mut() {
                channel_monitor_mut_references.push(channel_monitor);
            }
            let read_args = ChannelManagerReadArgs::new(
                keys_manager.clone(),
                fee_estimator.clone(),
                chain_monitor.clone(),
                broadcaster.clone(),
                logger.clone(),
                user_config,
                channel_monitor_mut_references,
            );
            <(BlockHash, ChannelManager)>::read(&mut f, read_args).unwrap()
        } else {
            // We're starting a fresh node.
            let (tip_height, tip_header) = lightning_wallet.get_tip().unwrap();
            let tip_hash = tip_header.block_hash();

            let chain_params = ChainParameters {
                network,
                best_block: BestBlock::new(tip_hash, tip_height),
            };
            let fresh_channel_manager = channelmanager::ChannelManager::new(
                fee_estimator.clone(),
                chain_monitor.clone(),
                broadcaster.clone(),
                logger.clone(),
                keys_manager.clone(),
                user_config,
                chain_params,
            );
            (tip_hash, fresh_channel_manager)
        }
    };

    let channel_manager: Arc<ChannelManager> = Arc::new(channel_manager);

    // Make sure our filter is initialized with all the txs and outputs
    // that we need to be watching based on our set of channel monitors
    for (_, monitor) in channelmonitors.iter() {
        monitor.load_outputs_to_watch(&filter.clone());
    }

    // `Confirm` trait is not implemented on an individual ChannelMonitor
    // but on a tuple consisting of (channel_monitor, broadcaster, fee_estimator, logger)
    // this maps our channel monitors into a tuple that implements Confirm
    let mut confirmable_monitors = channelmonitors
        .into_iter()
        .map(|(_monitor_hash, channel_monitor)| {
            (
                channel_monitor,
                broadcaster.clone(),
                fee_estimator.clone(),
                logger.clone(),
            )
        })
        .collect::<Vec<ConfirmableMonitor>>();

    // construct and collect a Vec of references to objects that implement the Confirm trait
    // note: we chain the channel_manager into this Vec
    let confirmables: Vec<&dyn Confirm> = confirmable_monitors
        .iter()
        .map(|cm| cm as &dyn chain::Confirm)
        .chain(iter::once(&*channel_manager as &dyn chain::Confirm))
        .collect();

    // Step 10: Sync our channel monitors and channel manager to chain tip
    lightning_wallet.sync(confirmables).unwrap();

    // Step 11: Give ChannelMonitors to ChainMonitor to watch
    for confirmable_monitor in confirmable_monitors.drain(..) {
        let channel_monitor = confirmable_monitor.0;
        let funding_txo = channel_monitor.get_funding_txo().0;
        assert_eq!(
            chain_monitor.watch_channel(funding_txo, channel_monitor),
            ChannelMonitorUpdateStatus::Completed
        );
    }

    // Step 12: Optional: Initialize the P2PGossipSync
    let genesis = genesis_block(network).header.block_hash();
    let network_graph_path = format!("{ldk_data_dir}/network_graph");
    let network_graph = Arc::new(disk::read_network(
        Path::new(&network_graph_path),
        genesis,
        logger.clone(),
    ));

    let gossip_sync = Arc::new(P2PGossipSync::new(
        Arc::clone(&network_graph),
        None::<Arc<dyn chain::Access + Send + Sync>>,
        logger.clone(),
    ));

    // Step 13: Initialize the PeerManager
    let onion_messenger: Arc<OnionMessenger> = Arc::new(OnionMessenger::new(
        Arc::clone(&keys_manager),
        Arc::clone(&logger),
        IgnoringMessageHandler {},
    ));
    let mut ephemeral_bytes = [0; 32];
    let current_time = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    thread_rng().fill_bytes(&mut ephemeral_bytes);
    let lightning_msg_handler = MessageHandler {
        chan_handler: channel_manager.clone(),
        route_handler: gossip_sync.clone(),
        onion_message_handler: onion_messenger,
    };
    let peer_manager: Arc<PeerManager> = Arc::new(PeerManager::new(
        lightning_msg_handler,
        keys_manager.get_node_secret(Recipient::Node).unwrap(),
        current_time.try_into().unwrap(),
        &ephemeral_bytes,
        logger.clone(),
        IgnoringMessageHandler {},
    ));

    let system = LightningSystem {
        wallet: lightning_wallet,
        chain_monitor,
        channel_manager,
        peer_manager,
        network_graph,
        logger,
        keys_manager,
        persister,
        gossip_sync,
    };

    Ok(system)
}

pub async fn run_ldk(
    system: &LightningSystem,
    listening_port: u16,
    ldk_data_dir: &Path,
) -> Result<()> {
    let ldk_data_dir = ldk_data_dir.to_string_lossy().to_string();
    let peer_manager_connection_handler = system.peer_manager.clone();
    let stop_listen_connect = Arc::new(AtomicBool::new(false));
    let stop_listen = Arc::clone(&stop_listen_connect);
    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{listening_port}"))
            .await
            .expect("Failed to bind to listen port - is something else already listening on it?");
        loop {
            let peer_mgr = peer_manager_connection_handler.clone();
            let tcp_stream = listener.accept().await.unwrap().0;
            if stop_listen.load(Ordering::Acquire) {
                return;
            }
            tokio::spawn(async move {
                lightning_net_tokio::setup_inbound(
                    peer_mgr.clone(),
                    tcp_stream.into_std().unwrap(),
                )
                .await;
            });
        }
    });

    // TODO: Check if its ok to skip step 15 as the sync will be already triggered regularly from
    // flutter.

    // Step 16: Handle LDK Events
    let event_handler = move |event: &Event| {
        block_on(handle_ldk_event(event));
    };

    // Step 17: Initialize routing ProbabilisticScorer
    let scorer_path = format!("{ldk_data_dir}/scorer");
    let scorer = Arc::new(Mutex::new(disk::read_scorer(
        Path::new(&scorer_path),
        Arc::clone(&system.network_graph),
        Arc::clone(&system.logger),
    )));

    // Step 18: Create InvoicePayer
    let router = DefaultRouter::new(
        system.network_graph.clone(),
        system.logger.clone(),
        system.keys_manager.get_secure_random_bytes(),
        scorer.clone(),
    );
    let invoice_payer = Arc::new(InvoicePayer::new(
        system.channel_manager.clone(),
        router,
        system.logger.clone(),
        event_handler,
        payment::Retry::Timeout(Duration::from_secs(10)),
    ));

    // Step 19: Background Processing
    // TODO: Do we need to stop the background processor on the wallet, or will it be sufficient to
    // simple kill it with the app.
    let _background_processor = BackgroundProcessor::start(
        system.persister.clone(),
        invoice_payer.clone(),
        system.chain_monitor.clone(),
        system.channel_manager.clone(),
        GossipSync::p2p(system.gossip_sync.clone()),
        system.peer_manager.clone(),
        system.logger.clone(),
        Some(scorer),
    );
    let peer_data_path = format!("{ldk_data_dir}/channel_peer_data");
    let mut info = disk::read_channel_peer_data(Path::new(&peer_data_path))?;
    for (pubkey, peer_addr) in info.drain() {
        for chan_info in system.channel_manager.list_channels() {
            if pubkey == chan_info.counterparty.node_id {
                block_on(async {
                    let _ =
                        connect_peer_if_necessary(pubkey, peer_addr, system.peer_manager.clone())
                            .await;
                });
            }
        }
    }
    tracing::info!("Lightning network started");
    Ok(())
}

pub async fn handle_ldk_event(event: &Event) {
    tracing::debug!(?event, "Received lightning event");
    match event {
        Event::FundingGenerationReady { .. } => {} // insert handling code
        Event::PaymentReceived { .. } => {}        // insert handling code
        Event::PaymentClaimed { .. } => {}         // insert handling code
        Event::PaymentSent { .. } => {}            // insert handling code
        Event::PaymentFailed { .. } => {}          // insert handling code
        Event::PaymentPathSuccessful { .. } => {}  // insert handling code
        Event::PaymentPathFailed { .. } => {}      // insert handling code
        Event::ProbeSuccessful { .. } => {}        // insert handling code
        Event::ProbeFailed { .. } => {}            // insert handling code
        Event::HTLCHandlingFailed { .. } => {}     // insert handling code
        Event::PendingHTLCsForwardable { .. } => {} // insert handling code
        Event::SpendableOutputs { .. } => {}       // insert handling code
        Event::OpenChannelRequest { .. } => {}     // insert handling code
        Event::PaymentForwarded { .. } => {}       // insert handling code
        Event::ChannelClosed { .. } => {}          // insert handling code
        Event::DiscardFunding { .. } => {}         // insert handling code
    }
}

// taken from the ldk-bdk-sample (cli)
pub(crate) async fn connect_peer_if_necessary(
    pubkey: PublicKey,
    peer_addr: SocketAddr,
    peer_manager: Arc<PeerManager>,
) -> Result<()> {
    for node_pubkey in peer_manager.get_peer_node_ids() {
        if node_pubkey == pubkey {
            return Ok(());
        }
    }
    match lightning_net_tokio::connect_outbound(Arc::clone(&peer_manager), pubkey, peer_addr).await
    {
        Some(connection_closed_future) => {
            let mut connection_closed_future = Box::pin(connection_closed_future);
            loop {
                match futures::poll!(&mut connection_closed_future) {
                    std::task::Poll::Ready(_) => {
                        bail!("ERROR: Peer disconnected before we finished the handshake");
                    }
                    std::task::Poll::Pending => {}
                }
                // Avoid blocking the tokio context by sleeping a bit
                match peer_manager
                    .get_peer_node_ids()
                    .iter()
                    .find(|id| **id == pubkey)
                {
                    Some(_) => break,
                    None => tokio::time::sleep(Duration::from_millis(10)).await,
                }
            }
        }
        None => {
            bail!("ERROR: failed to connect to peer");
        }
    }
    Ok(())
}
