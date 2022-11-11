use std::path::PathBuf;
use std::str::FromStr;

use anyhow::bail;
use anyhow::Result;
use bdk::bitcoin;
use bdk::bitcoin::util::bip32::ExtendedPrivKey;
use bip39::Language;
use bip39::Mnemonic;
use bitcoin::Network;
use hkdf::Hkdf;
use sha2::Sha256;

#[derive(Clone)]
pub struct Bip39Seed {
    path: PathBuf,
    mnemonic: Mnemonic,
}

impl Bip39Seed {
    pub fn new(path: PathBuf) -> Result<Self> {
        let mut rng = rand::thread_rng();
        let mnemonic = Mnemonic::generate_in_with(&mut rng, Language::English, 12)?;
        Ok(Self { mnemonic, path })
    }

    /// Initialise a [`Seed`] from a path.
    /// Generates new seed if there was no seed found in the given path
    pub fn initialize(seed_file: PathBuf) -> Result<Self> {
        let seed = if !seed_file.exists() {
            tracing::info!("No seed found. Generating new seed");
            let seed = Self::new(seed_file)?;
            seed.write(false)?;
            seed
        } else {
            Bip39Seed::read_from(seed_file)?
        };
        Ok(seed)
    }

    pub fn seed(&self) -> [u8; 64] {
        // passing an empty string here is the expected argument if the seed should not be
        // additionally password protected (according to https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki#from-mnemonic-to-seed)
        self.mnemonic.to_seed_normalized("")
    }

    pub fn restore(&mut self, mnemonic: String) -> Result<()> {
        // TODO: we should probably think about creating a backup of the existing seed instead of
        // simply overwriting it.
        self.mnemonic = Mnemonic::from_str(&mnemonic)?;
        self.write(true)?;
        Ok(())
    }

    pub fn derive_extended_priv_key(&self, network: Network) -> Result<ExtendedPrivKey> {
        let mut ext_priv_key_seed = [0u8; 64];

        Hkdf::<Sha256>::new(None, &self.seed())
            .expand(b"BITCOIN_WALLET_SEED", &mut ext_priv_key_seed)
            .expect("array is of correct length");

        let ext_priv_key = ExtendedPrivKey::new_master(network, &ext_priv_key_seed)?;
        Ok(ext_priv_key)
    }

    pub fn get_seed_phrase(&self) -> Vec<String> {
        self.mnemonic.word_iter().map(|word| word.into()).collect()
    }

    // Read the entropy used to generate Mnemonic from disk
    fn read_from(path: PathBuf) -> Result<Self> {
        let bytes = std::fs::read(path.clone())?;
        let mnemonic = Mnemonic::from_entropy(&bytes)?;
        Ok(Bip39Seed { mnemonic, path })
    }

    // Store the entropy used to generate Mnemonic on disk
    fn write(&self, restore: bool) -> Result<()> {
        if self.path.exists() && !restore {
            let path = self.path.display();
            bail!("Refusing to overwrite file at {path}")
        }
        std::fs::write(self.path.as_path(), &self.mnemonic.to_entropy())?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::env::temp_dir;

    use crate::seed::Bip39Seed;

    #[test]
    fn create_bip39_seed() {
        let path = temp_dir();
        let seed = Bip39Seed::new(path).expect("seed to be generated");
        let phrase = seed.get_seed_phrase();
        assert_eq!(12, phrase.len());
    }

    #[test]
    fn reinitialised_seed_is_the_same() {
        let mut path = temp_dir();
        path.push("seed");
        let seed_1 = Bip39Seed::initialize(path.clone()).unwrap();
        let seed_2 = Bip39Seed::initialize(path).unwrap();
        assert_eq!(
            seed_1.mnemonic, seed_2.mnemonic,
            "Reinitialised wallet should contain the same mnemonic"
        );
        assert_eq!(
            seed_1.seed(),
            seed_2.seed(),
            "Seed derived from mnemonic should be the same"
        );
    }
}
