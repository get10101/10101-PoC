use crate::cfd::models::Cfd;
use crate::db::SqliteConnection;
use anyhow::Result;
use futures::TryStreamExt;

pub async fn load_cfds(conn: &mut SqliteConnection) -> Result<Vec<Cfd>> {
    let mut rows = sqlx::query!(
        r#"
            select
                cfd.id as id,
                custom_output_id,
                contract_symbol as "contract_symbol: crate::cfd::models::ContractSymbol",
                position as "position: crate::cfd::models::Position",
                leverage,
                updated,
                created,
                cfd_state.state as "state: crate::cfd::models::CfdState",
                quantity,
                expiry,
                open_price,
                close_price,
                liquidation_price,
                margin
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
            margin: row.margin,
            close_price: row.close_price,
        };

        cfds.push(cfd);
    }

    Ok(cfds)
}
