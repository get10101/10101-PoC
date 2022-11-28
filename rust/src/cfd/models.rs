use flutter_rust_bridge::frb;

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum ContractSymbol {
    BtcUsd,
}

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum Position {
    Long,
    Short,
}

#[frb]
#[derive(Debug, Clone, Copy, sqlx::Type)]
pub struct Order {
    #[frb(non_final)]
    pub leverage: i64,
    #[frb(non_final)]
    pub quantity: i64,
    #[frb(non_final)]
    pub contract_symbol: ContractSymbol,
    #[frb(non_final)]
    pub position: Position,
    #[frb(non_final)]
    pub open_price: f64,
}

#[derive(Debug, Clone, Copy, sqlx::Type)]
pub enum CfdState {
    Open,
    Closed,
    Failed,
}

pub struct Cfd {
    pub id: i64,
    pub custom_output_id: String,
    pub contract_symbol: ContractSymbol,
    pub position: Position,
    pub leverage: i64,
    pub updated: i64,
    pub created: i64,
    pub state: CfdState,
    pub quantity: i64,
    pub expiry: i64,
    pub open_price: f64,
    pub close_price: Option<f64>,
    pub liquidation_price: f64,
    pub margin: f64,
}

impl Cfd {
    pub fn derive_order(&self) -> Order {
        Order {
            leverage: self.leverage,
            quantity: self.quantity,
            contract_symbol: self.contract_symbol,
            position: self.position,
            open_price: self.open_price,
        }
    }
}
