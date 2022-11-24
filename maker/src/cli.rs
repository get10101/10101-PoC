use anyhow::Result;
use clap::Parser;
use std::env::current_dir;
use std::net::SocketAddr;
use std::path::PathBuf;

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
}

impl Opts {
    // use this method to parse the options from the cli.
    pub fn read() -> Opts {
        Opts::parse()
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
