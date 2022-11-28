// taken from ldk-bdk-sample
use crate::hex_utils;
use crate::lightning::NetGraph;
use crate::lightning::PeerInfo;
use anyhow::bail;
use anyhow::Result;
use bdk::bitcoin;
use bitcoin::BlockHash;
use chrono::Utc;
use lightning::routing::gossip::NetworkGraph;
use lightning::routing::scoring::ProbabilisticScorer;
use lightning::routing::scoring::ProbabilisticScoringParameters;
use lightning::util::logger::Level as LoggerLevel;
use lightning::util::logger::Logger;
use lightning::util::logger::Record;
use lightning::util::ser::ReadableArgs;
use lightning::util::ser::Writer;
use std::fs;
use std::fs::File;
use std::io::BufReader;
use std::net::ToSocketAddrs;
use std::path::Path;
use std::sync::Arc;
use tracing::Level;

pub struct FilesystemLogger {
    data_dir: String,
}
impl FilesystemLogger {
    pub(crate) fn new(data_dir: String) -> Self {
        let logs_path = format!("{}/logs", data_dir);
        fs::create_dir_all(logs_path.clone()).unwrap();
        Self {
            data_dir: logs_path,
        }
    }
}

fn to_tracing_log_level(log_level: LoggerLevel) -> Level {
    match log_level {
        LoggerLevel::Gossip => Level::TRACE,
        LoggerLevel::Trace => Level::TRACE,
        LoggerLevel::Debug => Level::DEBUG,
        LoggerLevel::Info => Level::INFO,
        LoggerLevel::Warn => Level::WARN,
        LoggerLevel::Error => Level::ERROR,
    }
}

impl Logger for FilesystemLogger {
    fn log(&self, record: &Record) {
        let raw_log = record.args.to_string();
        let log = format!(
            "{} {:<5} [{}:{}] {}\n",
            // Note that a "real" lightning node almost certainly does *not* want subsecond
            // precision for message-receipt information as it makes log entries a target for
            // deanonymization attacks. For testing, however, its quite useful.
            Utc::now().format("%Y-%m-%d %H:%M:%S%.3f"),
            record.level,
            record.module_path,
            record.line,
            raw_log
        );

        let log_level = to_tracing_log_level(record.level);

        // TODO: Distinguish between the log levels instead of logging
        // everything on trace
        tracing::debug!(
            target: "ldk",
            ?log_level,
            module_path = record.module_path,
            line = record.line,
            raw_log
        );

        let logs_file_path = format!("{}/logs.txt", self.data_dir.clone());
        fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(logs_file_path)
            .unwrap()
            .write_all(log.as_bytes())
            .unwrap();
    }
}

pub(crate) fn read_network(
    path: &Path,
    genesis_hash: BlockHash,
    logger: Arc<FilesystemLogger>,
) -> NetGraph {
    if let Ok(file) = File::open(path) {
        if let Ok(graph) = NetworkGraph::read(&mut BufReader::new(file), logger.clone()) {
            return graph;
        }
    }
    NetworkGraph::new(genesis_hash, logger)
}

pub(crate) fn read_scorer(
    path: &Path,
    graph: Arc<NetGraph>,
    logger: Arc<FilesystemLogger>,
) -> ProbabilisticScorer<Arc<NetGraph>, Arc<FilesystemLogger>> {
    let params = ProbabilisticScoringParameters::default();
    if let Ok(file) = File::open(path) {
        let args = (params.clone(), Arc::clone(&graph), Arc::clone(&logger));
        if let Ok(scorer) = ProbabilisticScorer::read(&mut BufReader::new(file), args) {
            return scorer;
        }
    }
    ProbabilisticScorer::new(params, graph, logger)
}

pub fn parse_peer_info(peer_pubkey_and_ip_addr: String) -> Result<PeerInfo> {
    let mut pubkey_and_addr = peer_pubkey_and_ip_addr.split('@');
    let pubkey = pubkey_and_addr.next();
    let peer_addr_str = pubkey_and_addr.next();
    if peer_addr_str.is_none() || peer_addr_str.is_none() {
        bail!("ERROR: incorrectly formatted peer info. Should be formatted as: `pubkey@host:port`");
    }

    let peer_addr = peer_addr_str
        .unwrap()
        .to_socket_addrs()
        .map(|mut r| r.next());
    if peer_addr.is_err() || peer_addr.as_ref().unwrap().is_none() {
        bail!("ERROR: couldn't parse pubkey@host:port into a socket address");
    }

    let pubkey = hex_utils::to_compressed_pubkey(pubkey.unwrap());
    if pubkey.is_none() {
        bail!("ERROR: unable to parse given pubkey for node");
    }

    Ok(PeerInfo {
        pubkey: pubkey.unwrap(),
        peer_addr: peer_addr.unwrap().unwrap(),
    })
}
