use anyhow::Result;
use bip39::Language;
use bip39::Mnemonic;

#[derive(Clone)]
pub struct Bip39Seed {
    pub seed: [u8; 64],
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

        // passing an empty string here is the expected argument if the seed should not be
        // additionally password protected (according to https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki#from-mnemonic-to-seed)
        let seed = mnemonic.to_seed_normalized("");

        Ok(Bip39Seed { seed, phrase })
    }
}

#[cfg(test)]
mod tests {
    use crate::seed::Bip39Seed;

    #[test]
    fn create_bip39_seed() {
        let seed = Bip39Seed::new().expect("seed to be generated");
        assert_eq!(12, seed.phrase.len());
    }
}
