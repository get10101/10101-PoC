use anyhow::anyhow;
use anyhow::bail;
use anyhow::Result;
use std::{error, fmt, io};
use bdk::bitcoin::util::bip32::ExtendedPrivKey;
use bdk::bitcoin::Network;
use hkdf::Hkdf;
use rand::Rng;
use sha2::Sha256;
use std::convert::TryInto;
use std::fmt::Debug;
use std::path::{Path, PathBuf};
use allo_isolate::ffi::{DartCObject, DartCObjectType, DartCObjectValue, DartNativeTypedData, DartTypedDataType};
use allo_isolate::ffi::DartCObjectType::DartTypedData;
use allo_isolate::IntoDart;
use bdk::database::MemoryDatabase;
use bdk::{bitcoin, KeychainKind, Wallet};
use bdk::wallet::AddressIndex;

pub const TAKER_WALLET_SEED_FILE: &str = "taker_seed";
pub const TAKER_WALLET_ID: &str = "taker-wallet";

pub const RANDOM_SEED_SIZE: usize = 256;

pub async fn build_wallet(data_dir: PathBuf) -> Result<String> {
    let wallet_seed_file = &data_dir.join(TAKER_WALLET_SEED_FILE);
    let wallet_seed = RandomSeed::initialize(wallet_seed_file).await?;
    let ext_priv_key = wallet_seed.derive_extended_priv_key(Network::Testnet)?;
    let mut wallet_dir = data_dir.clone();
    wallet_dir.push(TAKER_WALLET_ID);

    let wallet = Wallet::new(
        bdk::template::Bip84(ext_priv_key, KeychainKind::External),
        Some(bdk::template::Bip84(ext_priv_key, KeychainKind::Internal)),
        ext_priv_key.network,
        MemoryDatabase::new(),
    )?;

    let address = wallet.get_address(AddressIndex::LastUnused)?.to_string();

    Ok(address)
}


#[derive(Copy, Clone)]
pub struct RandomSeed([u8; RANDOM_SEED_SIZE]);

impl Debug for RandomSeed {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("RandomSeed").field(&"...").finish()
    }
}

impl RandomSeed {
    fn seed(&self) -> Vec<u8> {
        self.0.to_vec()
    }

    /// Initialize a [`Seed`] from a path.
    /// Generates new seed if there was no seed found in the given path
    pub async fn initialize(seed_file: &Path) -> Result<RandomSeed> {
        let seed = if !seed_file.exists() {
            let seed = RandomSeed::default();
            seed.write_to(seed_file).await?;
            seed
        } else {
            RandomSeed::read_from(seed_file).await?
        };
        Ok(RandomSeed::default())
    }

    pub fn derive_extended_priv_key(&self, network: Network) -> Result<ExtendedPrivKey> {
        let mut ext_priv_key_seed = [0u8; 64];

        Hkdf::<Sha256>::new(None, &self.seed())
            .expand(b"BITCOIN_WALLET_SEED", &mut ext_priv_key_seed)
            .expect("okm array is of correct length");

        let ext_priv_key = ExtendedPrivKey::new_master(network, &ext_priv_key_seed)?;

        Ok(ext_priv_key)
    }

    async fn read_from(path: &Path) -> Result<Self> {
        let bytes = tokio::fs::read(path).await?;

        let bytes = bytes
            .try_into()
            .map_err(|_| anyhow!("Bytes from seed file don't fit into array"))?;

        Ok(RandomSeed(bytes))
    }

    async fn write_to(&self, path: &Path) -> Result<()> {
        if path.exists() {
            let path = path.display();
            bail!("Refusing to overwrite file at {path}")
        }

        tokio::fs::write(path, &self.0).await?;

        Ok(())
    }
}

impl From<[u8; RANDOM_SEED_SIZE]> for RandomSeed {
    fn from(bytes: [u8; RANDOM_SEED_SIZE]) -> Self {
        Self(bytes)
    }
}

impl Default for RandomSeed {
    fn default() -> Self {
        let mut seed = [0u8; RANDOM_SEED_SIZE];
        rand::thread_rng().fill(&mut seed);

        Self(seed)
    }
}