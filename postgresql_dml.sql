INSERT INTO billing.client (
    client_id,
    category,
    status,
    created_at
) VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'STANDARD',
    'ACTIVE',
    '2026-08-01 09:00:00+03'
),
(
    '22222222-2222-2222-2222-222222222222',
    'PREMIUM',
    'ACTIVE',
    '2026-08-01 09:10:00+03'
);

INSERT INTO billing.account (
    account_id,
    client_id,
    account_number,
    currency,
    status,
    created_at
) VALUES
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '11111111-1111-1111-1111-111111111111',
    '40817810000000000001',
    'RUB',
    'ACTIVE',
    '2026-08-01 09:20:00+03'
),
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    '22222222-2222-2222-2222-222222222222',
    '40817810000000000002',
    'RUB',
    'ACTIVE',
    '2026-08-01 09:25:00+03'
);

INSERT INTO billing.bank_product (
    product_id,
    name,
    product_type,
    status,
    created_at
) VALUES
(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Дебетовая карта',
    'CARD',
    'ACTIVE',
    '2026-08-01 10:00:00+03'
),
(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'Расчётный счёт',
    'ACCOUNT',
    'ACTIVE',
    '2026-08-01 10:10:00+03'
);

INSERT INTO billing.tariff (
    tariff_id,
    product_id,
    name,
    client_category,
    operation_type,
    calculation_type,
    fixed_amount,
    percentage,
    min_amount,
    max_amount,
    currency,
    valid_from,
    valid_to,
    status
) VALUES
(
    'cccccccc-cccc-cccc-cccc-ccccccccccc1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Перевод базовый',
    'STANDARD',
    'TRANSFER',
    'PERCENT',
    NULL,
    1.0000,
    30.00,
    500.00,
    'RUB',
    '2026-01-01',
    NULL,
    'ACTIVE'
),
(
    'cccccccc-cccc-cccc-cccc-ccccccccccc2',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Перевод Premium',
    'PREMIUM',
    'TRANSFER',
    'PERCENT',
    NULL,
    0.5000,
    10.00,
    300.00,
    'RUB',
    '2026-01-01',
    NULL,
    'ACTIVE'
),
(
    'cccccccc-cccc-cccc-cccc-ccccccccccc3',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'Обслуживание карты',
    NULL,
    'CARD_SERVICE',
    'FIXED',
    199.00,
    NULL,
    NULL,
    NULL,
    'RUB',
    '2026-01-01',
    NULL,
    'ACTIVE'
),
(
    'cccccccc-cccc-cccc-cccc-ccccccccccc4',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'Валютный перевод',
    'STANDARD',
    'FX_TRANSFER',
    'FIXED_PLUS_PERCENT',
    50.00,
    0.5000,
    NULL,
    1000.00,
    'RUB',
    '2026-01-01',
    NULL,
    'ACTIVE'
);

INSERT INTO billing.benefit (
    benefit_id,
    client_id,
    product_id,
    benefit_type,
    discount_percent,
    discount_amount,
    free_operation_count,
    valid_from,
    valid_to,
    status
) VALUES
(
    'dddddddd-dddd-dddd-dddd-ddddddddddd1',
    '22222222-2222-2222-2222-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'PERCENT_DISCOUNT',
    20.0000,
    NULL,
    NULL,
    '2026-01-01',
    NULL,
    'ACTIVE'
);

INSERT INTO billing.exchange_rate (
    exchange_rate_id,
    base_currency,
    quote_currency,
    rate,
    rate_date,
    source
) VALUES
(
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
    'USD',
    'RUB',
    80.25000000,
    '2026-08-15',
    'CBR'
);

INSERT INTO billing.billing_event (
    event_id,
    account_id,
    product_id,
    operation_type,
    operation_amount,
    operation_currency,
    operation_at,
    source_system,
    status,
    created_at
) VALUES
(
    'f1111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'TRANSFER',
    15000.00,
    'RUB',
    '2026-08-15 10:00:00+03',
    'PAYMENT_PROCESSING',
    'PROCESSED',
    '2026-08-15 10:00:01+03'
),
(
    'f2222222-2222-2222-2222-222222222222',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'TRANSFER',
    10000.00,
    'RUB',
    '2026-08-15 11:00:00+03',
    'PAYMENT_PROCESSING',
    'PROCESSED',
    '2026-08-15 11:00:01+03'
),
(
    'f3333333-3333-3333-3333-333333333333',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'FX_TRANSFER',
    100.00,
    'USD',
    '2026-08-15 12:00:00+03',
    'PAYMENT_PROCESSING',
    'PROCESSED',
    '2026-08-15 12:00:01+03'
),
(
    'f4444444-4444-4444-4444-444444444444',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'TRANSFER',
    500.00,
    'RUB',
    '2026-08-15 13:00:00+03',
    'PAYMENT_PROCESSING',
    'PROCESSED',
    '2026-08-15 13:00:01+03'
);

INSERT INTO billing.periodic_charge (
    periodic_charge_id,
    client_id,
    product_id,
    operation_type,
    periodicity,
    next_charge_date,
    status,
    created_at
) VALUES
(
    '99999999-9999-9999-9999-999999999991',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'CARD_SERVICE',
    'MONTHLY',
    '2026-09-01',
    'ACTIVE',
    '2026-08-01 12:00:00+03'
);

INSERT INTO billing.charge (
    charge_id,
    billing_event_id,
    periodic_charge_id,
    tariff_id,
    benefit_id,
    exchange_rate_id,
    amount,
    currency,
    discount_amount,
    calculated_at,
    status
) VALUES
(
    '77777777-7777-7777-7777-777777777771',
    'f1111111-1111-1111-1111-111111111111',
    NULL,
    'cccccccc-cccc-cccc-cccc-ccccccccccc1',
    NULL,
    NULL,
    150.00,
    'RUB',
    0.00,
    '2026-08-15 10:00:02+03',
    'PAID'
),
(
    '77777777-7777-7777-7777-777777777772',
    'f2222222-2222-2222-2222-222222222222',
    NULL,
    'cccccccc-cccc-cccc-cccc-ccccccccccc2',
    'dddddddd-dddd-dddd-dddd-ddddddddddd1',
    NULL,
    40.00,
    'RUB',
    10.00,
    '2026-08-15 11:00:02+03',
    'PAID'
),
(
    '77777777-7777-7777-7777-777777777773',
    'f3333333-3333-3333-3333-333333333333',
    NULL,
    'cccccccc-cccc-cccc-cccc-ccccccccccc4',
    NULL,
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
    90.13,
    'RUB',
    0.00,
    '2026-08-15 12:00:02+03',
    'PAID'
),
(
    '77777777-7777-7777-7777-777777777774',
    NULL,
    '99999999-9999-9999-9999-999999999991',
    'cccccccc-cccc-cccc-cccc-ccccccccccc3',
    NULL,
    NULL,
    199.00,
    'RUB',
    0.00,
    '2026-08-01 12:01:00+03',
    'CALCULATED'
);

INSERT INTO billing.debit_order (
    debit_order_id,
    charge_id,
    account_id,
    amount,
    currency,
    purpose,
    status,
    attempt_count,
    created_at,
    updated_at
) VALUES
(
    '66666666-6666-6666-6666-666666666661',
    '77777777-7777-7777-7777-777777777771',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    150.00,
    'RUB',
    'Комиссия за перевод',
    'PAID',
    1,
    '2026-08-15 10:00:03+03',
    '2026-08-15 10:00:04+03'
),
(
    '66666666-6666-6666-6666-666666666662',
    '77777777-7777-7777-7777-777777777772',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    40.00,
    'RUB',
    'Комиссия за перевод',
    'PAID',
    1,
    '2026-08-15 11:00:03+03',
    '2026-08-15 11:00:04+03'
),
(
    '66666666-6666-6666-6666-666666666663',
    '77777777-7777-7777-7777-777777777773',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    90.13,
    'RUB',
    'Комиссия за валютный перевод',
    'PAID',
    1,
    '2026-08-15 12:00:03+03',
    '2026-08-15 12:00:04+03'
),
(
    '66666666-6666-6666-6666-666666666664',
    '77777777-7777-7777-7777-777777777774',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    199.00,
    'RUB',
    'Комиссия за обслуживание карты',
    'CREATED',
    0,
    '2026-08-01 12:01:01+03',
    NULL
);

INSERT INTO billing.adjustment (
    adjustment_id,
    charge_id,
    amount,
    reason,
    created_by,
    created_at
) VALUES
(
    '55555555-5555-5555-5555-555555555551',
    '77777777-7777-7777-7777-777777777771',
    -50.00,
    'Корректировка ошибочно рассчитанной комиссии',
    'billing_operator',
    '2026-08-16 09:00:00+03'
);

INSERT INTO billing.refund (
    refund_id,
    charge_id,
    amount,
    reason,
    status,
    created_at
) VALUES
(
    '44444444-4444-4444-4444-444444444441',
    '77777777-7777-7777-7777-777777777772',
    40.00,
    'Возврат комиссии по обращению клиента',
    'COMPLETED',
    '2026-08-17 14:00:00+03'
);
