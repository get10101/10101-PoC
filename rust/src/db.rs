use anyhow::anyhow;
use anyhow::bail;
use anyhow::Context;
use anyhow::Result;
use bdk::bitcoin::hashes::hex::FromHex;
use bdk::bitcoin::hashes::hex::ToHex;
use bdk::bitcoin::Txid;
use futures::TryStreamExt;
use sqlx::pool::PoolConnection;
use sqlx::sqlite::SqliteConnectOptions;
use sqlx::Sqlite;
use sqlx::SqlitePool;
use state::Storage;
use std::path::Path;
use std::sync::Mutex;
use std::sync::MutexGuard;

pub type SqliteConnection = PoolConnection<Sqlite>;

/// Wallet has to be managed by Rust as generics are not support by frb
static DB: Storage<Mutex<SqlitePool>> = Storage::new();

pub async fn init_db(sqlite_path: &Path) -> Result<()> {
    tracing::debug!(?sqlite_path, "SQLite database will be stored on disk");

    let pool = SqlitePool::connect_with(
        SqliteConnectOptions::new()
            .create_if_missing(true)
            .filename(sqlite_path),
    )
    .await?;

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .context("Failed to run migrations")?;

    DB.set(Mutex::new(pool));
    Ok(())
}

pub async fn acquire() -> Result<SqliteConnection> {
    let pool = get_db()
        .map_err(|e| anyhow!("cannot acquire DB lock: {e:#}"))?
        .clone();

    pool.acquire()
        .await
        .map_err(|e| anyhow!("cannot acquire connection: {e:#}"))
}

fn get_db() -> Result<MutexGuard<'static, SqlitePool>> {
    DB.try_get()
        .context("DB uninitialised")?
        .lock()
        .map_err(|_| anyhow!("cannot acquire DB lock"))
}

pub async fn load_ignore_txids() -> Result<Vec<(Txid, u64)>> {
    let mut conn = acquire().await?;

    let mut rows = sqlx::query!(
        r#"
            select
                txid,
                maker_amount
            from
                ignore_txid
            order by id
            "#
    )
    .fetch(&mut *conn);

    let mut ignore_txids = Vec::new();

    while let Some(row) = rows.try_next().await? {
        let txid = Txid::from_hex(row.txid.as_str())?;
        let maker_amount = row.maker_amount as u64;
        ignore_txids.push((txid, maker_amount));
    }

    Ok(ignore_txids)
}

pub async fn insert_ignore_txid(txid: Txid, maker_amount: i64) -> Result<()> {
    let mut conn = acquire().await?;

    let query_result = sqlx::query(
        r#"
        INSERT INTO ignore_txid (txid, maker_amount)
        VALUES ($1, $2)
        "#,
    )
    .bind(txid.to_hex())
    .bind(maker_amount)
    .execute(&mut conn)
    .await?;

    if query_result.rows_affected() != 1 {
        bail!("Failed to insert txid to be ignored");
    }

    tracing::info!("Successfully stored txid to be ignored");

    Ok(())
}
