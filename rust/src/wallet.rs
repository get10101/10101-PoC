use crate::seed::Bip39Seed;
use anyhow::bail;
use anyhow::Result;
use bdk::bitcoin::Network;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::KeychainKind;
use bdk::SyncOptions;
use bdk::Wallet;
use std::str::FromStr;

pub const MAINNET_ELECTRUM: &str = "ssl://blockstream.info:700";
pub const TESTNET_ELECTRUM: &str = "ssl://blockstream.info:993";

#[derive(Debug)]
pub struct WalletInfo {
    pub phrase: Vec<String>,
}

pub fn init_wallet(network: &str) -> Result<WalletInfo> {
    let network = Network::from_str(network)?;

    let electrum_url = match network {
        Network::Bitcoin => MAINNET_ELECTRUM,
        Network::Testnet => TESTNET_ELECTRUM,
        _ => bail!("Only public networks are supported"),
    };

    let seed = Bip39Seed::new()?;
    let ext_priv_key = seed.derive_extended_priv_key(Network::Testnet)?;

    let client = Client::new(electrum_url)?;
    let blockchain = ElectrumBlockchain::from(client);

    let wallet = Wallet::new(
        bdk::template::Bip84(ext_priv_key, KeychainKind::External),
        Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
        ext_priv_key.network,
        MemoryDatabase::new(),
    )?;

    wallet.sync(&blockchain, SyncOptions::default())?;

    Ok(WalletInfo {
        phrase: seed.phrase,
    })
}

#[cfg(test)]
mod tests {
    use crate::wallet;

    #[test]
    fn init_wallet_success() {
        wallet::init_wallet("bitcoin").expect("wallet to be initialized");
        wallet::init_wallet("testnet").expect("wallet to be initialized");
    }

    #[test]
    fn init_wallet_fail() {
        wallet::init_wallet("regtest").expect_err("wallet should not succeed to initialize");
        wallet::init_wallet("blabla").expect_err("wallet should not succeed to initialize");
    }
}
