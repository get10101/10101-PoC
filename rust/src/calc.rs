pub mod inverse {
    use rust_decimal::Decimal;

    pub fn calculate_long_liquidation_price(leverage: Decimal, price: Decimal) -> Decimal {
        price * leverage / (leverage + Decimal::ONE)
    }

    /// Calculate liquidation price for the party going short.
    pub fn calculate_short_liquidation_price(leverage: Decimal, price: Decimal) -> Decimal {
        // If the leverage is equal to 1, the liquidation price will go towards infinity
        if leverage == Decimal::ONE {
            return rust_decimal_macros::dec!(21_000_000);
        }
        price * leverage / (leverage - Decimal::ONE)
    }
}
