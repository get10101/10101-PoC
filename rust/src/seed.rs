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
    pub seed: [u8; 64],
    pub mnemonic: Mnemonic,
}

impl Bip39Seed {
    pub fn new() -> Result<Bip39Seed> {
        let mut rng = rand::thread_rng();
        let mnemonic = Mnemonic::generate_in_with(&mut rng, Language::English, 12)?;

        // passing an empty string here is the expected argument if the seed should not be
        // additionally password protected (according to https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki#from-mnemonic-to-seed)
        let seed = mnemonic.to_seed_normalized("");

        Ok(Bip39Seed { seed, mnemonic })
    }

    pub fn derive_extended_priv_key(&self, network: Network) -> Result<ExtendedPrivKey> {
        let mut ext_priv_key_seed = [0u8; 64];

        Hkdf::<Sha256>::new(None, &self.seed)
            .expand(b"BITCOIN_WALLET_SEED", &mut ext_priv_key_seed)
            .expect("array is of correct length");

        let ext_priv_key = ExtendedPrivKey::new_master(network, &ext_priv_key_seed)?;

        Ok(ext_priv_key)
    }

    pub fn get_seed_phrase(&self) -> Vec<String> {
        let phrase = self
            .mnemonic
            .to_string()
            .split(' ')
            .map(|word| word.into())
            .collect();
        phrase
    }
}

#[cfg(test)]
mod tests {
    use crate::seed::Bip39Seed;

    #[test]
    fn create_bip39_seed() {
        let seed = Bip39Seed::new().expect("seed to be generated");
        let phrase = seed.get_seed_phrase();
        assert_eq!(12, phrase.len());
    }
}
