CREATE SCHEMA IF NOT EXISTS billing;

CREATE TABLE billing.client (
    client_id UUID PRIMARY KEY,
    category VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT chk_client_category
        CHECK (category IN ('STANDARD', 'PREMIUM')),

    CONSTRAINT chk_client_status
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED'))
);

CREATE TABLE billing.account (
    account_id UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    account_number VARCHAR(34) NOT NULL UNIQUE,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_account_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT chk_account_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_account_status
        CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED'))
);

CREATE TABLE billing.bank_product (
    product_id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    product_type VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT chk_bank_product_type
        CHECK (product_type IN ('ACCOUNT', 'CARD', 'DEPOSIT', 'LOAN')),

    CONSTRAINT chk_bank_product_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED'))
);

CREATE TABLE billing.billing_event (
    event_id UUID PRIMARY KEY,
    account_id UUID NOT NULL,
    product_id UUID NOT NULL,
    operation_type VARCHAR(30) NOT NULL,
    operation_amount NUMERIC(15,2) NOT NULL,
    operation_currency VARCHAR(3) NOT NULL,
    operation_at TIMESTAMPTZ NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_billing_event_account
        FOREIGN KEY (account_id)
        REFERENCES billing.account(account_id),

    CONSTRAINT fk_billing_event_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_billing_event_operation_type
        CHECK (
            operation_type IN (
                'TRANSFER',
                'PAYMENT',
                'CASH_WITHDRAWAL',
                'CARD_SERVICE',
                'FX_TRANSFER'
            )
        ),

    CONSTRAINT chk_billing_event_amount
        CHECK (operation_amount > 0),

    CONSTRAINT chk_billing_event_currency
        CHECK (operation_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_billing_event_status
        CHECK (status IN ('NEW', 'PROCESSED', 'FAILED'))
);


CREATE TABLE billing.billing_operation (
    operation_id VARCHAR(64) PRIMARY KEY,
    external_operation_id VARCHAR(64) NOT NULL UNIQUE,
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    billing_event_id UUID NOT NULL UNIQUE,
    client_id UUID NOT NULL,
    account_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL,
    billing_decision VARCHAR(20) NOT NULL,
    decision_reason VARCHAR(30),
    commission_amount NUMERIC(15,2) NOT NULL,
    commission_currency VARCHAR(3) NOT NULL,
    charge_status VARCHAR(20) NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_billing_operation_event
        FOREIGN KEY (billing_event_id)
        REFERENCES billing.billing_event(event_id),

    CONSTRAINT fk_billing_operation_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_billing_operation_account
        FOREIGN KEY (account_id)
        REFERENCES billing.account(account_id),

    CONSTRAINT chk_billing_operation_status
        CHECK (
            status IN (
                'CALCULATED',
                'REJECTED',
                'COMPLETED',
                'CANCELLED',
                'ERROR'
            )
        ),

    CONSTRAINT chk_billing_operation_decision
        CHECK (billing_decision IN ('APPROVED', 'REJECTED')),

    CONSTRAINT chk_billing_operation_reason
        CHECK (
            decision_reason IS NULL
            OR decision_reason IN (
                'INSUFFICIENT_FUNDS',
                'ACCOUNT_BLOCKED',
                'ACCOUNT_CLOSED',
                'TARIFF_NOT_FOUND'
            )
        ),

    CONSTRAINT chk_billing_operation_decision_reason
        CHECK (
            (billing_decision = 'APPROVED' AND decision_reason IS NULL)
            OR
            (billing_decision = 'REJECTED' AND decision_reason IS NOT NULL)
        ),

    CONSTRAINT chk_billing_operation_commission_amount
        CHECK (commission_amount >= 0),

    CONSTRAINT chk_billing_operation_commission_currency
        CHECK (commission_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_billing_operation_charge_status
        CHECK (
            charge_status IN (
                'NO_CHARGE',
                'RESERVED',
                'PAID',
                'NOT_CHARGED',
                'PAYMENT_ERROR',
                'REFUNDED'
            )
        ),

    CONSTRAINT chk_billing_operation_version
        CHECK (version > 0),

    CONSTRAINT chk_billing_operation_dates
        CHECK (updated_at >= created_at)
);

CREATE TABLE billing.tariff (
    tariff_id UUID PRIMARY KEY,
    product_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    client_category VARCHAR(30),
    operation_type VARCHAR(30) NOT NULL,
    calculation_type VARCHAR(30) NOT NULL,
    fixed_amount NUMERIC(15,2),
    percentage NUMERIC(7,4),
    min_amount NUMERIC(15,2),
    max_amount NUMERIC(15,2),
    currency VARCHAR(3) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT fk_tariff_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_tariff_client_category
        CHECK (
            client_category IS NULL
            OR client_category IN ('STANDARD', 'PREMIUM')
        ),

    CONSTRAINT chk_tariff_operation_type
        CHECK (
            operation_type IN (
                'TRANSFER',
                'PAYMENT',
                'CASH_WITHDRAWAL',
                'CARD_SERVICE',
                'FX_TRANSFER'
            )
        ),

    CONSTRAINT chk_tariff_calculation_type
        CHECK (
            calculation_type IN (
                'FIXED',
                'PERCENT',
                'FIXED_PLUS_PERCENT'
            )
        ),

    CONSTRAINT chk_tariff_fixed_amount
        CHECK (
            fixed_amount IS NULL
            OR fixed_amount >= 0
        ),

    CONSTRAINT chk_tariff_percentage
        CHECK (
            percentage IS NULL
            OR (percentage >= 0 AND percentage <= 100)
        ),

    CONSTRAINT chk_tariff_min_amount
        CHECK (
            min_amount IS NULL
            OR min_amount >= 0
        ),

    CONSTRAINT chk_tariff_max_amount
        CHECK (
            max_amount IS NULL
            OR max_amount >= 0
        ),

    CONSTRAINT chk_tariff_amount_range
        CHECK (
            max_amount IS NULL
            OR min_amount IS NULL
            OR max_amount >= min_amount
        ),

    CONSTRAINT chk_tariff_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_tariff_valid_period
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        ),

    CONSTRAINT chk_tariff_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),

    CONSTRAINT chk_tariff_calculation
        CHECK (
            (
                calculation_type = 'FIXED'
                AND fixed_amount IS NOT NULL
            )
            OR
            (
                calculation_type = 'PERCENT'
                AND percentage IS NOT NULL
            )
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
    discount_percent NUMERIC(7,4),
    discount_amount NUMERIC(15,2),
    free_operation_count INTEGER,
    valid_from DATE NOT NULL,
    valid_to DATE,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT fk_benefit_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_benefit_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_benefit_type
        CHECK (
            benefit_type IN (
                'PERCENT_DISCOUNT',
                'FIXED_DISCOUNT',
                'FREE_OPERATIONS'
            )
        ),

    CONSTRAINT chk_benefit_discount_percent
        CHECK (
            discount_percent IS NULL
            OR (discount_percent >= 0 AND discount_percent <= 100)
        ),

    CONSTRAINT chk_benefit_discount_amount
        CHECK (
            discount_amount IS NULL
            OR discount_amount >= 0
        ),

    CONSTRAINT chk_benefit_free_operations
        CHECK (
            free_operation_count IS NULL
            OR free_operation_count >= 0
        ),

    CONSTRAINT chk_benefit_valid_period
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        ),

    CONSTRAINT chk_benefit_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'EXPIRED')),

    CONSTRAINT chk_benefit_type_value
        CHECK (
            (
                benefit_type = 'PERCENT_DISCOUNT'
                AND discount_percent IS NOT NULL
            )
            OR
            (
                benefit_type = 'FIXED_DISCOUNT'
                AND discount_amount IS NOT NULL
            )
            OR
            (
                benefit_type = 'FREE_OPERATIONS'
                AND free_operation_count IS NOT NULL
            )
        )
);

CREATE TABLE billing.exchange_rate (
    exchange_rate_id UUID PRIMARY KEY,
    base_currency VARCHAR(3) NOT NULL,
    quote_currency VARCHAR(3) NOT NULL,
    rate NUMERIC(18,8) NOT NULL,
    rate_date DATE NOT NULL,
    source VARCHAR(50) NOT NULL,

    CONSTRAINT uq_exchange_rate
        UNIQUE (
            base_currency,
            quote_currency,
            rate_date,
            source
        ),

    CONSTRAINT chk_exchange_rate_base_currency
        CHECK (base_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_exchange_rate_quote_currency
        CHECK (quote_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_exchange_rate_positive
        CHECK (rate > 0),

    CONSTRAINT chk_exchange_rate_currencies
        CHECK (base_currency <> quote_currency)
);

CREATE TABLE billing.periodic_charge (
    periodic_charge_id UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    product_id UUID NOT NULL,
    operation_type VARCHAR(30) NOT NULL,
    periodicity VARCHAR(20) NOT NULL,
    next_charge_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_periodic_charge_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_periodic_charge_product
        FOREIGN KEY (product_id)
        REFERENCES billing.bank_product(product_id),

    CONSTRAINT chk_periodic_charge_operation_type
        CHECK (
            operation_type IN (
                'TRANSFER',
                'PAYMENT',
                'CASH_WITHDRAWAL',
                'CARD_SERVICE',
                'FX_TRANSFER'
            )
        ),

    CONSTRAINT chk_periodic_charge_periodicity
        CHECK (
            periodicity IN (
                'DAILY',
                'WEEKLY',
                'MONTHLY',
                'YEARLY'
            )
        ),

    CONSTRAINT chk_periodic_charge_status
        CHECK (status IN ('ACTIVE', 'PAUSED', 'CLOSED'))
);

CREATE TABLE billing.charge (
    charge_id UUID PRIMARY KEY,
    billing_event_id UUID UNIQUE,
    periodic_charge_id UUID,
    tariff_id UUID NOT NULL,
    benefit_id UUID,
    exchange_rate_id UUID,
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    discount_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    calculated_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,

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

    CONSTRAINT chk_charge_amount
        CHECK (amount >= 0),

    CONSTRAINT chk_charge_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_charge_discount_amount
        CHECK (discount_amount >= 0),

    CONSTRAINT chk_charge_status
        CHECK (status IN ('CALCULATED', 'PAID', 'FAILED', 'REFUNDED')),

    CONSTRAINT chk_charge_source
        CHECK (
            (
                billing_event_id IS NOT NULL
                AND periodic_charge_id IS NULL
            )
            OR
            (
                billing_event_id IS NULL
                AND periodic_charge_id IS NOT NULL
            )
        )
);

CREATE TABLE billing.debit_order (
    debit_order_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL UNIQUE,
    account_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    purpose VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ,

    CONSTRAINT fk_debit_order_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id),

    CONSTRAINT fk_debit_order_account
        FOREIGN KEY (account_id)
        REFERENCES billing.account(account_id),

    CONSTRAINT chk_debit_order_amount
        CHECK (amount > 0),

    CONSTRAINT chk_debit_order_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_debit_order_status
        CHECK (
            status IN (
                'CREATED',
                'PROCESSING',
                'PAID',
                'FAILED'
            )
        ),

    CONSTRAINT chk_debit_order_attempt_count
        CHECK (attempt_count >= 0),

    CONSTRAINT chk_debit_order_dates
        CHECK (
            updated_at IS NULL
            OR updated_at >= created_at
        )
);

CREATE TABLE billing.adjustment (
    adjustment_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    reason TEXT NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_adjustment_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id),

    CONSTRAINT chk_adjustment_amount
        CHECK (amount <> 0)
);

CREATE TABLE billing.refund (
    refund_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_refund_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id),

    CONSTRAINT chk_refund_amount
        CHECK (amount > 0),

    CONSTRAINT chk_refund_status
        CHECK (
            status IN (
                'CREATED',
                'PROCESSING',
                'COMPLETED',
                'FAILED'
            )
        )
);



CREATE TABLE billing.outbox_event (
    event_id UUID PRIMARY KEY,
    charge_id UUID NOT NULL,
    client_id UUID NOT NULL,
    refund_id UUID,
    event_type VARCHAR(30) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    correlation_id VARCHAR(100) NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'NEW',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    published_at TIMESTAMPTZ,

    CONSTRAINT fk_outbox_event_charge
        FOREIGN KEY (charge_id)
        REFERENCES billing.charge(charge_id),

    CONSTRAINT fk_outbox_event_client
        FOREIGN KEY (client_id)
        REFERENCES billing.client(client_id),

    CONSTRAINT fk_outbox_event_refund
        FOREIGN KEY (refund_id)
        REFERENCES billing.refund(refund_id),

    CONSTRAINT chk_outbox_event_type
        CHECK (
            event_type IN (
                'COMMISSION_PAID',
                'COMMISSION_FAILED',
                'COMMISSION_REFUNDED'
            )
        ),

    CONSTRAINT chk_outbox_event_amount
        CHECK (amount >= 0),

    CONSTRAINT chk_outbox_event_currency
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT chk_outbox_event_status
        CHECK (
            status IN (
                'NEW',
                'PUBLISHED',
                'FAILED'
            )
        ),

    CONSTRAINT chk_outbox_event_attempt_count
        CHECK (attempt_count >= 0),

    CONSTRAINT chk_outbox_event_published_at
        CHECK (
            published_at IS NULL
            OR published_at >= created_at
        )
);

CREATE INDEX idx_account_client_id
    ON billing.account(client_id);

CREATE INDEX idx_billing_event_account_id
    ON billing.billing_event(account_id);

CREATE INDEX idx_billing_event_product_id
    ON billing.billing_event(product_id);

CREATE INDEX idx_billing_operation_client_id
    ON billing.billing_operation(client_id);

CREATE INDEX idx_billing_operation_account_id
    ON billing.billing_operation(account_id);

CREATE INDEX idx_billing_operation_status
    ON billing.billing_operation(status);

CREATE INDEX idx_tariff_product_id
    ON billing.tariff(product_id);

CREATE INDEX idx_tariff_lookup
    ON billing.tariff(
        product_id,
        operation_type,
        status,
        valid_from,
        valid_to
    );

CREATE INDEX idx_benefit_client_product
    ON billing.benefit(client_id, product_id);

CREATE INDEX idx_periodic_charge_client_id
    ON billing.periodic_charge(client_id);

CREATE INDEX idx_periodic_charge_product_id
    ON billing.periodic_charge(product_id);

CREATE INDEX idx_charge_periodic_charge_id
    ON billing.charge(periodic_charge_id);

CREATE INDEX idx_charge_tariff_id
    ON billing.charge(tariff_id);

CREATE INDEX idx_charge_benefit_id
    ON billing.charge(benefit_id);

CREATE INDEX idx_charge_exchange_rate_id
    ON billing.charge(exchange_rate_id);

CREATE INDEX idx_debit_order_account_id
    ON billing.debit_order(account_id);

CREATE INDEX idx_adjustment_charge_id
    ON billing.adjustment(charge_id);

CREATE INDEX idx_refund_charge_id
    ON billing.refund(charge_id);

CREATE INDEX idx_outbox_event_status_created_at
    ON billing.outbox_event(status, created_at);

CREATE INDEX idx_outbox_event_charge_id
    ON billing.outbox_event(charge_id);

CREATE INDEX idx_outbox_event_client_id
    ON billing.outbox_event(client_id);

CREATE INDEX idx_outbox_event_refund_id
    ON billing.outbox_event(refund_id);
