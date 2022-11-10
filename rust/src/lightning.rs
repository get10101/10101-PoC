use crate::disk::FilesystemLogger;
use anyhow::Result;
use bdk::bitcoin;
use bdk::bitcoin::BlockHash;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use lightning::chain;
use lightning::chain::chainmonitor;
use lightning::chain::channelmonitor::ChannelMonitor;
use lightning::chain::keysinterface::InMemorySigner;
use lightning::chain::keysinterface::KeysManager;
use lightning::chain::BestBlock;
use lightning::chain::ChannelMonitorUpdateStatus;
use lightning::chain::Confirm;
use lightning::chain::Filter;
use lightning::chain::Watch;
use lightning::ln::channelmanager;
use lightning::ln::channelmanager::ChainParameters;
use lightning::ln::channelmanager::ChannelManagerReadArgs;
use lightning::ln::channelmanager::SimpleArcChannelManager;
use lightning::ln::peer_handler::SimpleArcPeerManager;
use lightning::ln::PaymentHash;
use lightning::ln::PaymentPreimage;
use lightning::ln::PaymentSecret;
use lightning::routing::gossip::NetworkGraph;
use lightning::routing::scoring::ProbabilisticScorer;
use lightning::util::config::UserConfig;
use lightning::util::ser::ReadableArgs;
use lightning_invoice::payment;
use lightning_invoice::utils::DefaultRouter;
use lightning_net_tokio::SocketDescriptor;
use lightning_persister::FilesystemPersister;
use std::collections::HashMap;
use std::fmt;
use std::iter;
use std::path::Path;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::SystemTime;

pub struct LightningSystem {
    // TODO: do we really need all these Arcs? I'm just following examples for
    // now, but it might be an overkill here
    pub wallet: Arc<BdkLdkWallet>,
    chain_monitor: Arc<ChainMonitor>,
    channel_manager: Arc<ChannelManager>,
}

impl LightningSystem {
    pub fn confirmables(&self) -> Vec<&dyn Confirm> {
        vec![
            &*self.channel_manager as &dyn chain::Confirm,
            &*self.chain_monitor as &dyn chain::Confirm,
        ]
    }
}

pub(crate) enum HTLCStatus {
    Pending,
    Succeeded,
    Failed,
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

pub(crate) struct PaymentInfo {
    preimage: Option<PaymentPreimage>,
    secret: Option<PaymentSecret>,
    status: HTLCStatus,
    amt_msat: MillisatAmount,
}

pub(crate) type PaymentInfoStorage = Arc<Mutex<HashMap<PaymentHash, PaymentInfo>>>;

pub(crate) type BdkLdkWallet = bdk_ldk::LightningWallet<ElectrumBlockchain, MemoryDatabase>;

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
        if let Ok(mut f) = std::fs::File::open(format!("{}/manager", ldk_data_dir.clone())) {
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

    Ok(LightningSystem {
        wallet: lightning_wallet,
        chain_monitor,
        channel_manager,
    })
}
