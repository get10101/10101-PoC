use std::path::PathBuf;
use tokio::runtime::Runtime;
use allo_isolate::Isolate;
use bdk::bitcoin;
use bdk::database::MemoryDatabase;
use crate::wallet;
use crate::wallet::RandomSeed;
use bdk::wallet::wallet_name_from_descriptor;
use bdk::KeychainKind;
use bdk::wallet::Wallet;
use secp256k1::Secp256k1;
use anyhow::Result;

pub fn build_wallet(port: i64, data_dir: String) -> i32 {
    let rt = Runtime::new().unwrap();
    rt.block_on(async move {
        let data_dir = PathBuf::from(data_dir.as_str());
        let result = wallet::build_wallet(data_dir).await;

        // todo: add error handling.
        let address = result.expect("address");
        let isolate = Isolate::new(port);
        isolate.post(address);
    });
    1
}


