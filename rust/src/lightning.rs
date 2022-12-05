use crate::db::insert_payment;
use crate::db::load_payment;
use crate::db::update_payment;
use crate::db::PaymentNewInfo;
use crate::disk;
use crate::disk::FilesystemLogger;
use crate::hex_utils;
use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin;
use bdk::bitcoin::blockdata::constants::genesis_block;
use bdk::bitcoin::hashes::Hash;
use bdk::bitcoin::secp256k1::PublicKey;
use bdk::bitcoin::secp256k1::Secp256k1;
use bdk::bitcoin::Amount;
use bdk::bitcoin::BlockHash;
use bdk::bitcoin::Network;
use bdk::blockchain::ElectrumBlockchain;
use bdk::wallet::time::get_timestamp;
use bitcoin_bech32::WitnessProgram;
use lightning::chain;
use lightning::chain::chaininterface::BroadcasterInterface;
use lightning::chain::chaininterface::ConfirmationTarget;
use lightning::chain::chaininterface::FeeEstimator;
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
use lightning::ln::PaymentHash;
use lightning::ln::PaymentPreimage;
use lightning::ln::PaymentSecret;
use lightning::onion_message::SimpleArcOnionMessenger;
use lightning::routing::gossip::NetworkGraph;
use lightning::routing::gossip::NodeId;
use lightning::routing::gossip::P2PGossipSync;
use lightning::routing::scoring::ProbabilisticScorer;
use lightning::util::config::ChannelHandshakeConfig;
use lightning::util::config::ChannelHandshakeLimits;
use lightning::util::config::UserConfig;
use lightning::util::events::Event;
use lightning::util::events::EventHandler;
use lightning::util::events::PaymentPurpose;
use lightning::util::ser::ReadableArgs;
use lightning_background_processor::BackgroundProcessor;
use lightning_background_processor::GossipSync;
use lightning_invoice::payment;
use lightning_invoice::payment::PaymentError;
use lightning_invoice::utils::DefaultRouter;
use lightning_invoice::Currency;
use lightning_invoice::Invoice;
use lightning_net_tokio::SocketDescriptor;
use lightning_persister::FilesystemPersister;
use rand::thread_rng;
use rand::Rng;
use rand::RngCore;
use serde::Serialize;
use state::Storage;
use std::fmt;
use std::fmt::Display;
use std::fmt::Formatter;
use std::iter;
use std::net::SocketAddr;
use std::path::Path;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::Duration;
use std::time::SystemTime;
use tokio::runtime;
use tokio::task::JoinHandle;

/// has to be managed by Rust as generics are not support by frb
static INVOICE_PAYER: Storage<Mutex<Arc<BdkLdkInvoicePayer>>> = Storage::new();

#[derive(Serialize)]
pub struct NodeInfo {
    pub node_id: PublicKey,
    pub num_channels: usize,
    pub num_usable_channels: usize,
    pub num_peers: usize,
    pub peers: Vec<PublicKey>,
}

/// Container to keep all the components of the lightning network in one place
#[derive(Clone)]
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
    pub data_dir: PathBuf,
    pub network: Network,
}

#[derive(Serialize)]
pub struct PeerInfo {
    pub pubkey: PublicKey,
    pub peer_addr: SocketAddr,
}

impl Display for PeerInfo {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        format!("{}@{}", self.pubkey, self.peer_addr).fmt(f)
    }
}

impl LightningSystem {
    pub fn confirmables(&self) -> Vec<&dyn Confirm> {
        vec![
            &*self.channel_manager as &dyn chain::Confirm,
            &*self.chain_monitor as &dyn chain::Confirm,
        ]
    }

    pub fn node_info(&self) -> NodeInfo {
        NodeInfo {
            node_id: self.channel_manager.get_our_node_id(),
            num_channels: self.channel_manager.list_channels().len(),
            num_usable_channels: self.channel_manager.list_usable_channels().len(),
            num_peers: self.peer_manager.get_peer_node_ids().len(),
            peers: self.peer_manager.get_peer_node_ids(),
        }
    }
}

pub async fn open_channel(
    channel_manager: Arc<ChannelManager>,
    peer_info: PeerInfo,
    channel_amount_sat: u64,
    initial_send_amount_sats: u64,
) -> Result<()> {
    let user_config = default_user_config();

    let _temp_channel_id = channel_manager
        .create_channel(
            peer_info.pubkey,
            channel_amount_sat,
            initial_send_amount_sats * 1000,
            0,
            Some(user_config),
        )
        .map_err(|e| anyhow!("Could not create channel with {peer_info} due to {e:?}"))?;

    tracing::info!("Started channel creation with {peer_info}");
    Ok(())
}

/// Closes the _first_ channel with a peer.
pub async fn close_channel(
    channel_manager: Arc<ChannelManager>,
    remote_node_id: PublicKey,
    force: bool,
) -> Result<()> {
    let channel_list = channel_manager.list_channels();
    let channel = channel_list
        .iter()
        .find(|details| details.counterparty.node_id == remote_node_id)
        .context("No channel with peer")?;

    if force {
        channel_manager
            .force_close_broadcasting_latest_txn(&channel.channel_id, &channel.counterparty.node_id)
            .map_err(|e| anyhow!("Could not force-close channel: {e:?}"))?;
        tracing::info!("Channel has been successfully force-closed");
    } else {
        channel_manager
            .close_channel(&channel.channel_id, &channel.counterparty.node_id)
            .map_err(|e| anyhow!("Could not collaborative-close channel: {e:?}"))?;
        tracing::info!("Channel collaborative-close triggered successfully");
    };

    Ok(())
}

#[derive(Clone, Debug, PartialEq, Eq, sqlx::Type)]
pub enum HTLCStatus {
    Pending,
    Succeeded,
    Failed,
}

/// Direction of the lightning payment
#[derive(Clone, Debug, PartialEq, Eq, sqlx::Type)]
pub enum Flow {
    Inbound,
    Outbound,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MillisatAmount(pub Option<u64>);

impl fmt::Display for MillisatAmount {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self.0 {
            Some(amt) => write!(f, "{}", amt),
            None => write!(f, "unknown"),
        }
    }
}

impl From<MillisatAmount> for Amount {
    fn from(ma: MillisatAmount) -> Self {
        match ma.0 {
            None => Amount::ZERO,
            Some(msats) => Amount::from_sat(msats / 1000),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PaymentInfo {
    pub hash: PaymentHash,
    pub preimage: Option<PaymentPreimage>,
    pub secret: Option<PaymentSecret>,
    pub flow: Flow,
    pub status: HTLCStatus,
    pub amt_msat: MillisatAmount,
    pub created_timestamp: u64,
    pub updated_timestamp: u64,
    pub expiry_timestamp: Option<u64>,
}

impl PaymentInfo {
    pub fn new(
        hash: PaymentHash,
        preimage: Option<PaymentPreimage>,
        secret: Option<PaymentSecret>,
        flow: Flow,
        status: HTLCStatus,
        amt_msat: MillisatAmount,
        expiry_timestamp: Option<u64>,
    ) -> Self {
        Self {
            hash,
            preimage,
            secret,
            flow,
            status,
            amt_msat,
            created_timestamp: get_timestamp(),
            updated_timestamp: get_timestamp(),
            expiry_timestamp,
        }
    }
}

pub(crate) type BdkLdkWallet = bdk_ldk::LightningWallet<ElectrumBlockchain, bdk::sled::Tree>;

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

pub(crate) type BdkLdkInvoicePayer =
    payment::InvoicePayer<Arc<ChannelManager>, Router, Arc<FilesystemLogger>, BdkLdkEventHandler>;

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
    data_dir: &Path,
    seed: &[u8; 32],
) -> Result<LightningSystem> {
    let lightning_wallet = Arc::new(lightning_wallet);
    let ldk_data_dir = data_dir.join("ldk").to_string_lossy().to_string();

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
    let mut channelmonitors = persister.read_channelmonitors(keys_manager.clone())?;

    // TODO: This is new, check whether this is needed
    // Step 9: Poll for the best chain tip, which may be used by the channel manager & spv client
    // let polled_chain_tip = init::validate_best_block_header(lightning_wallet.as_ref())
    //     .await
    //     .expect("Failed to fetch best block header and best block");

    // Step 9: Initialize the ChannelManager

    let user_config = default_user_config();

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
            <(BlockHash, ChannelManager)>::read(&mut f, read_args)
                .map_err(|e| anyhow::anyhow!("{e:?}"))?
        } else {
            // We're starting a fresh node.
            let (tip_height, tip_header) = lightning_wallet
                .get_tip()
                .map_err(|e| anyhow::anyhow!("{e:?}"))?;
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
    lightning_wallet
        .sync(confirmables)
        .map_err(|e| anyhow::anyhow!("{e:?}"))?;

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
        .duration_since(SystemTime::UNIX_EPOCH)?
        .as_secs();
    thread_rng().fill_bytes(&mut ephemeral_bytes);
    let lightning_msg_handler = MessageHandler {
        chan_handler: channel_manager.clone(),
        route_handler: gossip_sync.clone(),
        onion_message_handler: onion_messenger,
    };
    let peer_manager: Arc<PeerManager> = Arc::new(PeerManager::new(
        lightning_msg_handler,
        keys_manager
            .get_node_secret(Recipient::Node)
            .map_err(|e| anyhow::anyhow!("{e:?}"))?,
        current_time.try_into()?,
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
        data_dir: Path::new(&ldk_data_dir).to_path_buf(),
        network,
    };

    Ok(system)
}

fn default_user_config() -> UserConfig {
    UserConfig {
        channel_handshake_limits: ChannelHandshakeLimits {
            trust_own_funding_0conf: false,
            ..Default::default()
        },
        channel_handshake_config: ChannelHandshakeConfig {
            announced_channel: true,
            minimum_depth: 1,
            ..Default::default()
        },
        // By setting `manually_accept_inbound_channels` to `true` we need to manually confirm every
        // inbound channel request.
        manually_accept_inbound_channels: false,
        ..Default::default()
    }
}

pub async fn run_ldk(system: &LightningSystem) -> Result<BackgroundProcessor> {
    let ldk_data_dir = system.data_dir.to_string_lossy().to_string();

    let runtime_handle = tokio::runtime::Handle::current();
    let event_handler = BdkLdkEventHandler {
        runtime_handle,
        channel_manager: system.channel_manager.clone(),
        wallet: system.wallet.clone(),
        network_graph: system.network_graph.clone(),
        keys_manager: system.keys_manager.clone(),
        network: system.network,
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
    let invoice_payer = Arc::new(BdkLdkInvoicePayer::new(
        system.channel_manager.clone(),
        router,
        system.logger.clone(),
        event_handler,
        payment::Retry::Timeout(Duration::from_secs(10)),
    ));

    INVOICE_PAYER.set(Mutex::new(invoice_payer.clone()));

    // Step 19: Background Processing
    let background_processor = BackgroundProcessor::start(
        system.persister.clone(),
        invoice_payer.clone(),
        system.chain_monitor.clone(),
        system.channel_manager.clone(),
        GossipSync::p2p(system.gossip_sync.clone()),
        system.peer_manager.clone(),
        system.logger.clone(),
        Some(scorer),
    );

    let node_id = system.channel_manager.get_our_node_id();

    tracing::info!("Lightning node started with node ID {node_id}");
    Ok(background_processor)
}

pub async fn run_ldk_server(
    system: &LightningSystem,
    address: SocketAddr,
) -> Result<(JoinHandle<()>, BackgroundProcessor)> {
    let peer_manager_connection_handler = system.peer_manager.clone();
    let stop_listen_connect = Arc::new(AtomicBool::new(false));
    let stop_listen = Arc::clone(&stop_listen_connect);
    let tcp_handle = tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(address)
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

    tracing::info!("Listening on {address}");

    let background_processor = run_ldk(system).await?;
    Ok((tcp_handle, background_processor))
}

pub async fn connect_peer_if_necessary(
    peer: &PeerInfo,
    peer_manager: Arc<PeerManager>,
) -> Result<()> {
    for node_pubkey in peer_manager.get_peer_node_ids() {
        if node_pubkey == peer.pubkey {
            return Ok(());
        }
    }
    match lightning_net_tokio::connect_outbound(
        Arc::clone(&peer_manager),
        peer.pubkey,
        peer.peer_addr,
    )
    .await
    {
        Some(connection_closed_future) => {
            tracing::info!("Connected with {peer}");
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
                    .find(|id| **id == peer.pubkey)
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

#[allow(clippy::too_many_arguments)]
async fn handle_ldk_events(
    channel_manager: Arc<ChannelManager>,
    wallet: Arc<BdkLdkWallet>,
    network_graph: &NetGraph,
    keys_manager: Arc<KeysManager>,
    network: Network,
    event: &Event,
) {
    tracing::debug!("Received {:?}", event);

    match event {
        Event::FundingGenerationReady {
            temporary_channel_id,
            channel_value_satoshis,
            output_script,
            counterparty_node_id,
            ..
        } => {
            // Construct the raw transaction with one output, that is paid the amount of the
            // channel.
            let _addr = WitnessProgram::from_scriptpubkey(
                &output_script[..],
                match network {
                    Network::Bitcoin => bitcoin_bech32::constants::Network::Bitcoin,
                    Network::Testnet => bitcoin_bech32::constants::Network::Testnet,
                    Network::Regtest => bitcoin_bech32::constants::Network::Regtest,
                    Network::Signet => panic!("Signet unsupported"),
                },
            )
            .expect("Lightning funding tx should always be to a SegWit output")
            .to_address();

            let target_blocks = 2;

            // Have wallet put the inputs into the transaction such that the output
            // is satisfied and then sign the funding transaction
            let funding_tx_result = wallet.construct_funding_transaction(
                output_script,
                *channel_value_satoshis,
                target_blocks,
            );

            let funding_tx = match funding_tx_result {
                Ok(funding_tx) => funding_tx,
                Err(e) => {
                    tracing::error!(
                        "Cannot open channel due to not being able to create funding tx {e:?}"
                    );
                    channel_manager
                        .close_channel(temporary_channel_id, counterparty_node_id)
                        .expect("To be able to close a channel we cannot open");
                    return;
                }
            };

            // Give the funding transaction back to LDK for opening the channel.

            if let Err(err) = channel_manager.funding_transaction_generated(
                temporary_channel_id,
                counterparty_node_id,
                funding_tx,
            ) {
                tracing::error!("Channel went away before we could fund it. The peer disconnected or refused the channel. {err:?}");
            }
        }
        Event::PaymentReceived {
            payment_hash,
            purpose,
            amount_msat,
            ..
        } => {
            tracing::info!(
                "EVENT: received payment from payment hash {} of {} millisatoshis",
                hex_utils::hex_str(&payment_hash.0),
                amount_msat,
            );
            let payment_preimage = match purpose {
                PaymentPurpose::InvoicePayment {
                    payment_preimage, ..
                } => *payment_preimage,
                PaymentPurpose::SpontaneousPayment(preimage) => Some(*preimage),
            };
            channel_manager.claim_funds(payment_preimage.unwrap());
        }
        Event::PaymentSent {
            payment_preimage,
            payment_hash,
            ..
        } => {
            let new_info = Some(PaymentNewInfo {
                preimage: Some(*payment_preimage),
                secret: None,
            });

            match update_payment(payment_hash, HTLCStatus::Succeeded, new_info).await {
                Ok(_) => tracing::info!(
                    "EVENT: successfully sent payment  from payment hash {:?}",
                    hex_utils::hex_str(&payment_hash.0),
                ),
                Err(e) => tracing::error!(?e),
            };
        }
        Event::PaymentPathFailed {
            payment_hash,
            payment_failed_permanently,
            all_paths_failed,
            short_channel_id,
            ..
        } => {
            let payment_fail_msg = format!(
                "EVENT: Failed to send payment{} to payment hash {:?}",
                if *all_paths_failed {
                    ""
                } else {
                    " along MPP path"
                },
                hex_utils::hex_str(&payment_hash.0)
            );

            let payment_fail_msg = if let Some(scid) = short_channel_id {
                payment_fail_msg + &format!(" because of failure at channel {}", scid)
            } else {
                payment_fail_msg
            };
            let payment_fail_msg = if *payment_failed_permanently {
                payment_fail_msg + ": re-attempting the payment will not succeed"
            } else {
                payment_fail_msg + ": exhausted payment retry attempts"
            };
            tracing::error!(payment_fail_msg);

            if let Err(e) = update_payment(payment_hash, HTLCStatus::Failed, None).await {
                tracing::error!(?e);
            }
        }
        Event::PaymentForwarded {
            fee_earned_msat,
            claim_from_onchain_tx,
            prev_channel_id,
            next_channel_id,
        } => {
            tracing::debug!(
                ?fee_earned_msat,
                ?claim_from_onchain_tx,
                ?prev_channel_id,
                ?next_channel_id,
                "Payment forwarded"
            );

            let read_only_network_graph = network_graph.read_only();
            let nodes = read_only_network_graph.nodes();
            let channels = channel_manager.list_channels();

            let node_str = |channel_id: &Option<[u8; 32]>| match channel_id {
                None => String::new(),
                Some(channel_id) => match channels.iter().find(|c| c.channel_id == *channel_id) {
                    None => String::new(),
                    Some(channel) => {
                        match nodes.get(&NodeId::from_pubkey(&channel.counterparty.node_id)) {
                            None => "private node".to_string(),
                            Some(node) => match &node.announcement_info {
                                None => "unnamed node".to_string(),
                                Some(announcement) => {
                                    format!("node {}", announcement.alias)
                                }
                            },
                        }
                    }
                },
            };
            let channel_str = |channel_id: &Option<[u8; 32]>| {
                channel_id
                    .map(|channel_id| format!(" with channel {}", hex_utils::hex_str(&channel_id)))
                    .unwrap_or_default()
            };
            let from_prev_str = format!(
                " from {}{}",
                node_str(prev_channel_id),
                channel_str(prev_channel_id)
            );
            let to_next_str = format!(
                " to {}{}",
                node_str(next_channel_id),
                channel_str(next_channel_id)
            );

            let from_onchain_str = if *claim_from_onchain_tx {
                "from onchain downstream claim"
            } else {
                "from HTLC fulfill message"
            };
            if let Some(fee_earned) = fee_earned_msat {
                tracing::debug!(
                    "\nEVENT: Forwarded payment{}{}, earning {} msat {}",
                    from_prev_str,
                    to_next_str,
                    fee_earned,
                    from_onchain_str
                );
            } else {
                tracing::debug!(
                    "\nEVENT: Forwarded payment{}{}, claiming onchain {}",
                    from_prev_str,
                    to_next_str,
                    from_onchain_str
                );
            }
        }
        Event::PendingHTLCsForwardable { time_forwardable } => {
            tracing::debug!("EVENT: pending HTLC Forwardable");
            let forwarding_channel_manager = channel_manager.clone();
            let min = time_forwardable.as_millis() as u64;
            tokio::task::spawn_blocking(move || {
                let millis_to_sleep = thread_rng().gen_range(min, min * 5) as u64;
                std::thread::sleep(Duration::from_millis(millis_to_sleep));
                forwarding_channel_manager.process_pending_htlc_forwards();
            })
            .await
            .unwrap();
        }
        Event::SpendableOutputs { outputs } => {
            tracing::debug!(?outputs, "EVENT: spendable outputs");
            let destination_address = wallet.get_unused_address().unwrap();
            let output_descriptors = &outputs.iter().collect::<Vec<_>>();
            let tx_feerate = wallet.get_est_sat_per_1000_weight(ConfirmationTarget::Normal);
            let spending_tx = keys_manager
                .spend_spendable_outputs(
                    output_descriptors,
                    Vec::new(),
                    destination_address.script_pubkey(),
                    tx_feerate,
                    &Secp256k1::new(),
                )
                .unwrap();
            wallet.broadcast_transaction(&spending_tx);
        }
        Event::ChannelClosed {
            channel_id,
            reason,
            user_channel_id: _,
        } => {
            tracing::info!(
                "EVENT: Channel {} closed due to: {:?}",
                hex_utils::hex_str(channel_id),
                reason
            );
        }
        Event::DiscardFunding { .. } => {
            // A "real" node should probably "lock" the UTXOs spent in funding transactions until
            // the funding transaction either confirms, or this event is generated.
            tracing::error!("Event::DiscardFunding is not yet implemented");
        }
        Event::PaymentFailed {
            payment_id,
            payment_hash,
        } => {
            tracing::info!(?payment_id, ?payment_hash, "EVENT: Payment path failed",);

            if let Err(e) = update_payment(payment_hash, HTLCStatus::Failed, None).await {
                tracing::error!(?e, "Unknown payment");
            }
        }
        Event::PaymentPathSuccessful {
            payment_id,
            payment_hash,
            path,
        } => {
            let payment_hash_str = if let Some(payment_hash) = payment_hash {
                hex_utils::hex_str(&payment_hash.0)
            } else {
                "NONE".to_string()
            };

            tracing::info!(
                ?path,
                "EVENT: Payment path successful from {payment_hash_str}",
            );

            if let Some(payment_hash) = payment_hash {
                match update_payment(payment_hash, HTLCStatus::Succeeded, None).await {
                    Ok(payment) => channel_manager.claim_funds(payment.preimage.unwrap()),
                    Err(e) => tracing::error!(?e, "Could not update payment"),
                }
            } else {
                tracing::error!(?payment_id, "no payment hash in successful payment path");
            }
        }
        Event::PaymentClaimed {
            payment_hash,
            purpose,
            amount_msat,
        } => {
            tracing::info!(
                "EVENT: claimed payment from payment hash {} of {} millisatoshis",
                hex_utils::hex_str(&payment_hash.0),
                amount_msat,
            );
            let (payment_preimage, payment_secret) = match purpose {
                PaymentPurpose::InvoicePayment {
                    payment_preimage,
                    payment_secret,
                } => (*payment_preimage, Some(*payment_secret)),
                PaymentPurpose::SpontaneousPayment(preimage) => (Some(*preimage), None),
            };

            if let Ok(payment) = load_payment(payment_hash).await {
                if let Err(e) = update_payment(
                    &payment.hash,
                    HTLCStatus::Succeeded,
                    Some(PaymentNewInfo {
                        preimage: payment_preimage,
                        secret: payment_secret,
                    }),
                )
                .await
                {
                    tracing::error!(?e);
                }
            } else {
                let payment = PaymentInfo::new(
                    *payment_hash,
                    payment_preimage,
                    payment_secret,
                    Flow::Inbound,
                    HTLCStatus::Succeeded,
                    MillisatAmount(Some(*amount_msat)),
                    None,
                );
                if let Err(e) = insert_payment(&payment).await {
                    {
                        tracing::error!(?e);
                    }
                }
            }
        }
        Event::ProbeSuccessful {
            payment_id,
            payment_hash,
            path,
        } => {
            tracing::debug!(?payment_id, ?payment_hash, ?path, "Probe successful");
        }
        Event::ProbeFailed {
            payment_id,
            payment_hash,
            path,
            short_channel_id,
        } => {
            tracing::error!(
                ?payment_id,
                ?payment_hash,
                ?path,
                ?short_channel_id,
                "Probe failed"
            )
        }
        Event::OpenChannelRequest {
            temporary_channel_id,
            counterparty_node_id,
            ..
        } => {
            let mut rng = rand::thread_rng();
            let user_channel_id = rng.gen();
            match channel_manager.accept_inbound_channel_from_trusted_peer_0conf(
                temporary_channel_id,
                counterparty_node_id,
                user_channel_id,
            ) {
                Ok(_) => {
                    tracing::debug!("Channel was opened successfully");
                }
                Err(e) => {
                    tracing::error!("Could not open channel due to {e:?}");
                }
            }
        }
        Event::HTLCHandlingFailed {
            prev_channel_id,
            failed_next_destination,
        } => {
            tracing::error!(
                ?prev_channel_id,
                ?failed_next_destination,
                "HTLC handling failed"
            );
        }
        // Maker
        Event::RemoteSentAddCustomOutputEvent { custom_output_id } => {
            // TODO: Remove unwrap
            let _details = channel_manager
                .continue_remote_add_custom_output(*custom_output_id)
                .unwrap();

            // TODO: Persist CFD details
        }
        // Maker
        Event::RemoteSentCustomOutputCommitmentSignature {
            commitment_signed,
            revoke_and_ack,
            public_key_remote,
        } => {
            if let Err(e) = channel_manager.manual_send_commitment_signed(
                *public_key_remote,
                commitment_signed.clone(),
                revoke_and_ack.clone(),
            ) {
                tracing::error!("Failed to manual send commitment signed: {e:#}");
            }
        }
    }
}

/// Lightning network event handler
pub struct BdkLdkEventHandler {
    runtime_handle: runtime::Handle,
    channel_manager: Arc<ChannelManager>,
    wallet: Arc<BdkLdkWallet>,
    network_graph: Arc<NetGraph>,
    keys_manager: Arc<KeysManager>,
    network: Network,
}

impl EventHandler for BdkLdkEventHandler {
    fn handle_event(&self, event: &Event) {
        self.runtime_handle.block_on(handle_ldk_events(
            self.channel_manager.clone(),
            self.wallet.clone(),
            &self.network_graph,
            self.keys_manager.clone(),
            self.network,
            event,
        ));
    }
}

pub async fn send_payment(invoice: &Invoice) -> Result<()> {
    let status = {
        let invoice_payer = INVOICE_PAYER
            .try_get()
            .context("LDK not running - no invoice payer")?
            .lock()
            .map_err(|e| anyhow!("could not acquire mutex: {e:#}"))?;
        match invoice_payer.pay_invoice(invoice) {
            Ok(_payment_id) => {
                let payee_pubkey = invoice.recover_payee_pub_key();
                let amt_msat = invoice
                    .amount_milli_satoshis()
                    .context("invalid msat amount in the invoice")?;
                tracing::info!("EVENT: initiated sending {amt_msat} msats to {payee_pubkey}",);
                HTLCStatus::Pending
            }
            Err(PaymentError::Invoice(e)) => {
                tracing::error!("Invalid invoice: {e}");
                anyhow::bail!(e);
            }
            Err(PaymentError::Routing(e)) => {
                tracing::error!("Failed to find route: {e:?}");
                anyhow::bail!("{:?}", e);
            }
            Err(PaymentError::Sending(e)) => {
                tracing::error!("Failed to send payment: {e:?}");
                HTLCStatus::Failed
            }
            Err(PaymentError::CreatingCustomOutput(e)) => {
                panic!("This variant should not happen: {:?}", e);
            }
            Err(PaymentError::RemovingCustomOutput(e)) => {
                panic!("This variant should not happen: {:?}", e);
            }
        }
    };
    let payment = PaymentInfo::new(
        PaymentHash((*invoice.payment_hash()).into_inner()),
        None,
        Some(*invoice.payment_secret()),
        Flow::Outbound,
        status,
        MillisatAmount(invoice.amount_milli_satoshis()),
        Some(invoice.duration_since_epoch().as_secs() + invoice.expiry_time().as_secs()),
    );
    insert_payment(&payment).await?;
    Ok(())
}

#[allow(clippy::too_many_arguments)]
pub async fn create_invoice(
    amt_msat: u64,
    channel_manager: Arc<ChannelManager>,
    keys_manager: Arc<KeysManager>,
    network: Network,
    description: String,
    expiry_secs: u32,
    logger: Arc<disk::FilesystemLogger>,
) -> Result<String> {
    let currency = match network {
        Network::Bitcoin => Currency::Bitcoin,
        Network::Testnet => Currency::BitcoinTestnet,
        Network::Regtest => Currency::Regtest,
        Network::Signet => bail!("Signet unsupported"),
    };
    let invoice = match lightning_invoice::utils::create_invoice_from_channelmanager(
        &channel_manager,
        keys_manager,
        logger,
        currency,
        Some(amt_msat),
        description,
        expiry_secs,
    ) {
        Ok(inv) => {
            tracing::debug!("Successfully generated invoice: {}", inv);
            inv
        }
        Err(e) => {
            bail!("Failed to create invoice: {:?}", e);
        }
    };

    let payment = PaymentInfo::new(
        PaymentHash((*invoice.payment_hash()).into_inner()),
        None,
        Some(*invoice.payment_secret()),
        Flow::Inbound,
        HTLCStatus::Pending,
        MillisatAmount(Some(amt_msat)),
        Some(get_timestamp() + expiry_secs as u64),
    );
    insert_payment(&payment).await?;
    Ok(invoice.to_string())
}
