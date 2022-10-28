use crate::seed::Bip39Seed;
use anyhow::Result;
use bdk::bitcoin::Network;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::KeychainKind;
use bdk::SyncOptions;
use bdk::Wallet;

pub fn init_wallet() -> Result<()> {
    let seed = Bip39Seed::new()?;
    let ext_priv_key = seed.derive_extended_priv_key(Network::Testnet)?;

    let client = Client::new("ssl://electrum.blockstream.info:60002")?;
    let blockchain = ElectrumBlockchain::from(client);

    let wallet = Wallet::new(
        bdk::template::Bip84(ext_priv_key, KeychainKind::External),
        Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
        ext_priv_key.network,
        MemoryDatabase::new(),
    )?;

    wallet.sync(&blockchain, SyncOptions::default())?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use crate::wallet;

    #[test]
    fn init_wallet() {
        wallet::init_wallet().expect("wallet to be initialized");
    }
}
