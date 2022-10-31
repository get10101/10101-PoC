use anyhow::Result;
use bdk::bitcoin;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::Balance;
use bdk::SyncOptions;

pub struct Wallet {
    blockchain: ElectrumBlockchain,
    wallet: bdk::Wallet<MemoryDatabase>,
}

impl Wallet {
    pub fn sync(&self) -> Result<Balance> {
        self.wallet.sync(&self.blockchain, SyncOptions::default())?;

        let balance = self.wallet.get_balance()?;
        println!("Descriptor balance: {} SAT", &balance);

        Ok(balance)
    }

    /// Initialised wallet will be managed by Rust as generics are not support by frb
    pub fn new() -> Result<Wallet> {
        let client = Client::new("ssl://electrum.blockstream.info:60002")?;
        let blockchain = ElectrumBlockchain::from(client);
        let wallet = bdk::Wallet::new(
            "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/0/*)",
            Some("wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/1/*)"),
            bitcoin::Network::Testnet,
            MemoryDatabase::default(),
        )?;
        Ok(Wallet { blockchain, wallet })
    }
}
