use crate::seed;
use crate::seed::Bip39Seed;
use anyhow::Result;
use bdk::bitcoin::Network;
use bdk::blockchain::ElectrumBlockchain;
use bdk::database::MemoryDatabase;
use bdk::electrum_client::Client;
use bdk::wallet::AddressIndex;
use bdk::KeychainKind;
use bdk::SyncOptions;
use bdk::Wallet;

#[derive(Clone)]
pub struct WalletInfo {
    pub address: String,
    pub balance: u64,
    pub phrase: Vec<String>,
}

pub struct TenTenOneWallet {
    seed: Bip39Seed,
    wallet: Wallet<MemoryDatabase>,
    blockchain: ElectrumBlockchain,
}

impl TenTenOneWallet {
    pub fn sync(&self) -> Result<WalletInfo> {
        self.wallet.sync(&self.blockchain, SyncOptions::default())?;

        let balance = self.wallet.get_balance()?.confirmed;
        let address_info = self.wallet.get_address(AddressIndex::LastUnused)?;
        let address = address_info.address.to_string();
        let phrase = &self.seed.phrase;

        Ok(WalletInfo {
            address,
            balance,
            phrase: phrase.to_vec(),
        })
    }
}

pub fn init_wallet() -> Result<TenTenOneWallet> {
    let seed = seed::Bip39Seed::new()?;
    let ext_priv_key = seed.derive_extended_priv_key(Network::Testnet)?; // todo: this should be configurable.

    let client = Client::new("ssl://electrum.blockstream.info:60002")?;
    let blockchain = ElectrumBlockchain::from(client);

    let wallet = Wallet::new(
        bdk::template::Bip84(ext_priv_key, KeychainKind::External),
        Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
        ext_priv_key.network,
        MemoryDatabase::new(),
    )?;
    Ok(TenTenOneWallet {
        seed,
        wallet,
        blockchain,
    })
}
