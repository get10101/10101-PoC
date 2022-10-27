use bdk::bitcoin;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::Balance;
use bdk::SyncOptions;
use bdk::Wallet;

// TODO: Split these calls up
pub fn init_wallet() -> anyhow::Result<Balance> {
    let client = Client::new("ssl://electrum.blockstream.info:60002")?;
    let blockchain = ElectrumBlockchain::from(client);
    let wallet = Wallet::new(
        "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/0/*)",
        Some("wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/1/*)"),
        bitcoin::Network::Testnet,
        MemoryDatabase::default(),
    )?;

    wallet.sync(&blockchain, SyncOptions::default())?;

    let balance = wallet.get_balance()?;
    println!("Descriptor balance: {} SAT", &balance);

    Ok(balance)
}
