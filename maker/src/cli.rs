use anyhow::Result;
use clap::Parser;
use std::env::current_dir;
use std::net::SocketAddr;
use std::path::PathBuf;
use ten_ten_one::wallet::MAINNET_ELECTRUM;
use ten_ten_one::wallet::REGTEST_ELECTRUM;
use ten_ten_one::wallet::TESTNET_ELECTRUM;

#[derive(Parser)]
pub struct Opts {
    /// The IP address to listen on for the HTTP API.
    #[clap(long, default_value = "127.0.0.1:8000")]
    pub http_address: SocketAddr,

    /// The address to listen on for the lightning peer2peer API.
    #[clap(long, default_value = "127.0.0.1:9045")]
    pub lightning_p2p_address: SocketAddr,

    /// Where to permanently store data, defaults to the current working directory.
    #[clap(long)]
    data_dir: Option<PathBuf>,

    #[clap(subcommand)]
    network: Option<Network>,
}

impl Opts {
    // use this method to parse the options from the cli.
    pub fn read() -> Opts {
        Opts::parse()
    }

    pub fn network(&self) -> ten_ten_one::wallet::Network {
        match self.network {
            None => ten_ten_one::wallet::Network::Regtest,
            Some(Network::Mainnet { .. }) => ten_ten_one::wallet::Network::Mainnet,
            Some(Network::Testnet { .. }) => ten_ten_one::wallet::Network::Testnet,
            Some(Network::Regtest { .. }) => ten_ten_one::wallet::Network::Regtest,
        }
    }

    pub fn electrum(&self) -> String {
        match &self.network {
            None => REGTEST_ELECTRUM,
            Some(Network::Mainnet { electrum })
            | Some(Network::Testnet { electrum })
            | Some(Network::Regtest { electrum }) => electrum,
        }
        .to_string()
    }

    pub fn data_dir(&self) -> Result<PathBuf> {
        let data_dir = match self.data_dir.clone() {
            None => current_dir()?.join("data"),
            Some(path) => path,
        }
        .join("maker");
        Ok(data_dir)
    }
}

#[derive(Parser, Clone)]
pub enum Network {
    /// Run on mainnet (default)
    Mainnet {
        /// URL to the electrum backend to use for the wallet.
        #[clap(long, default_value = MAINNET_ELECTRUM)]
        electrum: String,
    },
    /// Run on testnet
    Testnet {
        /// URL to the electrum backend to use for the wallet.
        #[clap(long, default_value = TESTNET_ELECTRUM)]
        electrum: String,
    },
    /// Run on regtest
    Regtest {
        /// URL to the electrum backend to use for the wallet.
        #[clap(long, default_value = REGTEST_ELECTRUM)]
        electrum: String,
    },
}
