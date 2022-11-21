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

pub mod quanto {
    use rust_decimal::Decimal;
    use rust_decimal::RoundingStrategy;

    /// Compute the closing price under which the party going long should get liquidated.
    pub fn bankruptcy_price_long(initial_price: Decimal, leverage: Decimal) -> Decimal {
        let shift = bankruptcy_price_shift(initial_price, leverage);

        initial_price - shift
    }

    /// Compute the closing price over which the party going short should get liquidated.
    pub fn bankruptcy_price_short(initial_price: Decimal, leverage: Decimal) -> Decimal {
        let shift = bankruptcy_price_shift(initial_price, leverage);

        initial_price + shift
    }

    /// By how much the price of the asset needs to shift from the initial price in order to reach
    /// the bankruptcy price of the party with the given `leverage`.
    ///
    /// This is an absolute value. How to apply it in order to calculate the bankruptcy price will
    /// depend on the party's position.
    fn bankruptcy_price_shift(initial_price: Decimal, leverage: Decimal) -> Decimal {
        let shift = initial_price / leverage;
        shift.round_dp_with_strategy(0, RoundingStrategy::ToZero)
    }
}
