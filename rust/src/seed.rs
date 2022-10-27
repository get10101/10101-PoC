use anyhow::Result;
use bdk::bitcoin::secp256k1::rand;
use bdk::bitcoin::util::bip32::ExtendedPrivKey;
use bdk::bitcoin::Network;
use bip39::Language;
use bip39::Mnemonic;
use hkdf::Hkdf;
use sha2::Sha256;

#[derive(Clone)]
pub struct Bip39Seed {
    seed: [u8; 64],
    pub phrase: Vec<String>,
}

impl Bip39Seed {
    pub fn new() -> Result<Bip39Seed> {
        let mut rng = rand::thread_rng();
        let mnemonic = Mnemonic::generate_in_with(&mut rng, Language::English, 12)?;

        let phrase = mnemonic
            .to_string()
            .split(' ')
            .map(|word| word.into())
            .collect();
        let seed = mnemonic.to_seed_normalized("");

        Ok(Bip39Seed { seed, phrase })
    }

    pub fn derive_extended_priv_key(&self, network: Network) -> Result<ExtendedPrivKey> {
        let mut ext_priv_key_seed = [0u8; 64];

        Hkdf::<Sha256>::new(None, &self.seed)
            .expand(b"BITCOIN_WALLET_SEED", &mut ext_priv_key_seed)
            .expect("okm array is of correct length");

        let ext_priv_key = ExtendedPrivKey::new_master(network, &ext_priv_key_seed)?;

        Ok(ext_priv_key)
    }
}
