CREATE SCHEMA IF NOT EXISTS billing;

CREATE TABLE billing.client (
    client_id UUID PRIMARY KEY,
    category VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE billing.account (
    account_id UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    account_number VARCHAR(34) NOT NULL UNIQUE,
    currency VARCHAR(3) NOT NULL
        CHECK (char_length(currency) = 3),
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_account_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id)
);

CREATE TABLE billing.bank_product (
    product_id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    product_type VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE billing.billing_event (
    event_id UUID PRIMARY KEY,
    account_id UUID NOT NULL,
    product_id UUID NOT NULL,
    operation_type VARCHAR(30) NOT NULL,
    operation_amount NUMERIC(15,2) NOT NULL
        CHECK (operation_amount > 0),
    operation_currency VARCHAR(3) NOT NULL
        CHECK (char_length(operation_currency) = 3),
    operation_at TIMESTAMPTZ NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'REJECTED', 'ERROR')),
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_billing_event_account
        FOREIGN KEY (account_id)
        REFERENCES billing.account(account_id),

    CONSTRAINT fk_billing_event_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id)
);

CREATE TABLE billing.tariff (
    tariff_id UUID PRIMARY KEY,
    product_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    client_category VARCHAR(30),
    operation_type VARCHAR(30) NOT NULL,
    calculation_type VARCHAR(30) NOT NULL
        CHECK (
            calculation_type IN (
                'FIXED',
                'PERCENT',
                'FIXED_PLUS_PERCENT'
            )
        ),
    fixed_amount NUMERIC(15,2)
        CHECK (fixed_amount IS NULL OR fixed_amount >= 0),
    percentage NUMERIC(7,4)
        CHECK (percentage IS NULL OR percentage >= 0),
    min_amount NUMERIC(15,2)
        CHECK (min_amount IS NULL OR min_amount >= 0),
    max_amount NUMERIC(15,2)
        CHECK (max_amount IS NULL OR max_amount >= 0),
    currency VARCHAR(3) NOT NULL
        CHECK (char_length(currency) = 3),
    valid_from DATE NOT NULL,
    valid_to DATE,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'INACTIVE')),

    CONSTRAINT fk_tariff_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_tariff_period
        CHECK (valid_to IS NULL OR valid_to >= valid_from),

    CONSTRAINT chk_tariff_amounts
        CHECK (max_amount IS NULL OR min_amount IS NULL OR max_amount >= min_amount),

    CONSTRAINT chk_tariff_calculation
        CHECK (
            (calculation_type = 'FIXED' AND fixed_amount IS NOT NULL)
            OR
            (calculation_type = 'PERCENT' AND percentage IS NOT NULL)
            OR
            (
                calculation_type = 'FIXED_PLUS_PERCENT'
                AND fixed_amount IS NOT NULL
                AND percentage IS NOT NULL
            )
        )
);

CREATE TABLE billing.benefit (
    benefit_id UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    product_id UUID NOT NULL,
    benefit_type VARCHAR(30) NOT NULL,
    discount_percent NUMERIC(7,4)
        CHECK (
            discount_percent IS NULL
            OR (discount_percent >= 0 AND discount_percent <= 100)
        ),
    discount_amount NUMERIC(15,2)
        CHECK (discount_amount IS NULL OR discount_amount >= 0),
    free_operation_count INTEGER
        CHECK (free_operation_count IS NULL OR free_operation_count >= 0),
    valid_from DATE NOT NULL,
    valid_to DATE,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'INACTIVE')),

    CONSTRAINT fk_benefit_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_benefit_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_benefit_period
        CHECK (valid_to IS NULL OR valid_to >= valid_from),

    CONSTRAINT chk_benefit_value
        CHECK (
            discount_percent IS NOT NULL
            OR discount_amount IS NOT NULL
            OR free_operation_count IS NOT NULL
        )
);

CREATE TABLE billing.exchange_rate (
    exchange_rate_id UUID PRIMARY KEY,
    base_currency VARCHAR(3) NOT NULL
        CHECK (char_length(base_currency) = 3),
    quote_currency VARCHAR(3) NOT NULL
        CHECK (char_length(quote_currency) = 3),
    rate NUMERIC(18,8) NOT NULL
        CHECK (rate > 0),
    rate_date DATE NOT NULL,
    source VARCHAR(50) NOT NULL,

    CONSTRAINT uq_exchange_rate
        UNIQUE (base_currency, quote_currency, rate_date, source),

    CONSTRAINT chk_exchange_currency
        CHECK (base_currency <> quote_currency)
);

CREATE TABLE billing.periodic_charge (
    periodic_charge_id UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    product_id UUID NOT NULL,
    operation_type VARCHAR(30) NOT NULL,
    periodicity VARCHAR(20) NOT NULL
        CHECK (
            periodicity IN (
                'DAILY',
                'WEEKLY',
                'MONTHLY',
                'YEARLY'
            )
        ),
    next_charge_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('ACTIVE', 'PAUSED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_periodic_charge_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_periodic_charge_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id)
);

CREATE TABLE billing.charge (
    charge_id UUID PRIMARY KEY,
    billing_event_id UUID UNIQUE,
    periodic_charge_id UUID,
    tariff_id UUID NOT NULL,
    benefit_id UUID,
    exchange_rate_id UUID,
    amount NUMERIC(15,2) NOT NULL
        CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL
        CHECK (char_length(currency) = 3),
    discount_amount NUMERIC(15,2) NOT NULL DEFAULT 0
        CHECK (discount_amount >= 0),
    calculated_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (
            status IN (
                'CALCULATED',
                'PENDING_PAYMENT',
                'PAID',
                'REJECTED',
                'CANCELLED',
                'REFUNDED',
                'ERROR'
            )
        ),

    CONSTRAINT fk_charge_billing_event
        FOREIGN KEY (billing_event_id)
        REFERENCES billing.billing_event(event_id),

    CONSTRAINT fk_charge_periodic_charge
        FOREIGN KEY (periodic_charge_id)
        REFERENCES billing.periodic_charge(periodic_charge_id),

    CONSTRAINT fk_charge_tariff
        FOREIGN KEY (tariff_id)
        REFERENCES billing.tariff(tariff_id),

    CONSTRAINT fk_charge_benefit
        FOREIGN KEY (benefit_id)
        REFERENCES billing.benefit(benefit_id),

    CONSTRAINT fk_charge_exchange_rate
        FOREIGN KEY (exchange_rate_id)
        REFERENCES billing.exchange_rate(exchange_rate_id),

    CONSTRAINT chk_charge_source
        CHECK (
            (billing_event_id IS NOT NULL AND periodic_charge_id IS NULL)
            OR
            (billing_event_id IS NULL AND periodic_charge_id IS NOT NULL)
        )
);

CREATE TABLE billing.debit_order (
    debit_order_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL UNIQUE,
    account_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL
        CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL
        CHECK (char_length(currency) = 3),
    purpose VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (
            status IN (
                'PENDING',
                'PROCESSING',
                'PAID',
                'FAILED',
                'CANCELLED'
            )
        ),
    attempt_count INTEGER NOT NULL DEFAULT 0
        CHECK (attempt_count >= 0),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ,

    CONSTRAINT fk_debit_order_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id),

    CONSTRAINT fk_debit_order_account
        FOREIGN KEY (account_id)
        REFERENCES billing.account(account_id),

    CONSTRAINT chk_debit_order_dates
        CHECK (updated_at IS NULL OR updated_at >= created_at)
);

CREATE TABLE billing.adjustment (
    adjustment_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL
        CHECK (amount <> 0),
    reason TEXT NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_adjustment_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id)
);

CREATE TABLE billing.refund (
    refund_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL
        CHECK (amount > 0),
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('CREATED', 'PROCESSING', 'COMPLETED', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_refund_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id)
);

CREATE INDEX idx_account_client_id
    ON billing.account(client_id);

CREATE INDEX idx_billing_event_account_id
    ON billing.billing_event(account_id);

CREATE INDEX idx_billing_event_product_id
    ON billing.billing_event(product_id);

CREATE INDEX idx_tariff_product_id
    ON billing.tariff(product_id);

CREATE INDEX idx_tariff_lookup
    ON billing.tariff(product_id, operation_type, status, valid_from, valid_to);

CREATE INDEX idx_benefit_client_product
    ON billing.benefit(client_id, product_id);

CREATE INDEX idx_periodic_charge_client_id
    ON billing.periodic_charge(client_id);

CREATE INDEX idx_periodic_charge_product_id
    ON billing.periodic_charge(product_id);

CREATE INDEX idx_charge_tariff_id
    ON billing.charge(tariff_id);

CREATE INDEX idx_charge_periodic_charge_id
    ON billing.charge(periodic_charge_id);

CREATE INDEX idx_debit_order_account_id
    ON billing.debit_order(account_id);

CREATE INDEX idx_adjustment_charge_id
    ON billing.adjustment(charge_id);

CREATE INDEX idx_refund_charge_id
    ON billing.refund(charge_id);
