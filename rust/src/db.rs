use crate::cfd::Cfd;
use anyhow::anyhow;
use anyhow::Context;
use anyhow::Result;
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

pub async fn load_cfds(conn: &mut SqliteConnection) -> Result<Vec<Cfd>> {
    let mut rows = sqlx::query!(
        r#"
            select
                cfd.id as id,
                custom_output_id,
                contract_symbol as "contract_symbol: crate::cfd::ContractSymbol",
                position as "position: crate::cfd::Position",
                leverage,
                updated,
                created,
                cfd_state.state as "state: crate::cfd::CfdState",
                quantity,
                expiry,
                open_price,
                liquidation_price
            from
                cfd
            inner join cfd_state on cfd.state_id = cfd_state.id
            "#
    )
    .fetch(&mut *conn);

    let mut cfds = Vec::new();

    while let Some(row) = rows.try_next().await? {
        let cfd = Cfd {
            id: row.id,
            position: row.position,
            open_price: row.open_price,
            leverage: row.leverage,
            updated: row.updated,
            created: row.created,
            state: row.state,
            quantity: row.quantity,
            custom_output_id: row.custom_output_id,
            contract_symbol: row.contract_symbol,
            expiry: row.expiry,
            liquidation_price: row.liquidation_price,
        };

        cfds.push(cfd);
    }

    Ok(cfds)
}
