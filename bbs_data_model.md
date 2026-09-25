# Модель данных Banking Billing System

## 1. Концептуальная модель данных в нотации Чена

![Концептуальная модель данных](bbs_chen_notation.svg)

---

## 2. Логическая/физическая модель данных в нотации Мартина

![Логическая/физическая модель данных](bbs_martin_notation.svg)

 
### 2.1. Табличная часть

#### Сущность `client`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| client_id | UUID | PK | Уникальный идентификатор клиента |
| category | VARCHAR(30) | NOT NULL, CHECK (category IN ('STANDARD', 'PREMIUM')) | Категория клиента |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')) | Статус клиента |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `account`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| account_id | UUID | PK | Уникальный идентификатор счёта |
| client_id | UUID | FK, NOT NULL | Ссылка на клиента |
| account_number | VARCHAR(34) | NOT NULL, UNIQUE | Номер банковского счёта |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')) | Статус счёта |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания счёта |

#### Сущность `bank_product`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| product_id | UUID | PK | Уникальный идентификатор банковского продукта |
| name | VARCHAR(100) | NOT NULL | Название банковского продукта |
| product_type | VARCHAR(30) | NOT NULL, CHECK (product_type IN ('ACCOUNT', 'CARD', 'DEPOSIT', 'LOAN')) | Тип банковского продукта |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')) | Статус банковского продукта |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `billing_event`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| event_id | UUID | PK | Уникальный идентификатор биллингового события |
| account_id | UUID | FK, NOT NULL | Счёт, связанный с операцией |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| operation_type | VARCHAR(30) | NOT NULL, CHECK (operation_type IN ('TRANSFER', 'PAYMENT', 'CASH_WITHDRAWAL', 'CARD_SERVICE', 'FX_TRANSFER')) | Тип операции |
| operation_amount | NUMERIC(15,2) | NOT NULL, CHECK (operation_amount > 0) | Сумма операции |
| operation_currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| operation_at | TIMESTAMPTZ | NOT NULL | Дата и время операции |
| source_system | VARCHAR(50) | NOT NULL | Система-источник события |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('NEW', 'PROCESSED', 'FAILED')) | Статус обработки события |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `billing_operation`

Техническая таблица хранит состояние REST-операции, созданной при предварительном расчёте комиссии, и связывает REST-контракт с биллинговым событием.

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| operation_id | VARCHAR(64) | PK | Идентификатор биллинговой операции, возвращаемый через REST API |
| external_operation_id | VARCHAR(64) | NOT NULL, UNIQUE | Идентификатор денежной операции в системе денежных переводов |
| idempotency_key | VARCHAR(64) | NOT NULL, UNIQUE | Ключ идемпотентности POST-запроса |
| billing_event_id | UUID | FK, NOT NULL, UNIQUE | Биллинговое событие, созданное для операции |
| client_id | UUID | FK, NOT NULL | Клиент |
| account_id | UUID | FK, NOT NULL | Счёт клиента |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('CALCULATED', 'REJECTED', 'COMPLETED', 'CANCELLED', 'ERROR')) | Состояние REST-операции |
| billing_decision | VARCHAR(20) | NOT NULL, CHECK (billing_decision IN ('APPROVED', 'REJECTED')) | Решение о возможности продолжения операции |
| decision_reason | VARCHAR(30) | CHECK (decision_reason IN ('INSUFFICIENT_FUNDS', 'ACCOUNT_BLOCKED', 'ACCOUNT_CLOSED', 'TARIFF_NOT_FOUND')) | Причина отказа |
| commission_amount | NUMERIC(15,2) | NOT NULL, CHECK (commission_amount >= 0) | Рассчитанная комиссия |
| commission_currency | VARCHAR(3) | NOT NULL | Валюта комиссии по ISO 4217 |
| charge_status | VARCHAR(20) | NOT NULL, CHECK (charge_status IN ('NO_CHARGE', 'RESERVED', 'PAID', 'NOT_CHARGED', 'PAYMENT_ERROR', 'REFUNDED')) | Состояние комиссии в REST-контракте |
| version | INTEGER | NOT NULL, DEFAULT 1, CHECK (version > 0) | Версия ресурса для формирования ETag |
| created_at | TIMESTAMPTZ | NOT NULL | Дата создания операции |
| updated_at | TIMESTAMPTZ | NOT NULL, CHECK (updated_at >= created_at) | Дата последнего изменения |

`billing_operation` не является отдельной бизнес-сущностью концептуальной модели Чена. Таблица используется как техническое состояние REST-ресурса: хранит `operationId`, `externalOperationId`, `Idempotency-Key`, предварительно рассчитанную комиссию, статус операции и версию для `ETag`.

Для операций системы денежных переводов `external_operation_id` используется как идентификатор корреляции и переносится в `outbox_event.correlation_id` при формировании асинхронного события.

При `transferStatus = CANCELLED` операция переводится в статус `CANCELLED`; денежный перевод, запись `charge` и списание комиссии не выполняются.

#### Сущность `tariff`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| tariff_id | UUID | PK | Уникальный идентификатор тарифа |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| name | VARCHAR(100) | NOT NULL | Название тарифа |
| client_category | VARCHAR(30) | CHECK (client_category IN ('STANDARD', 'PREMIUM')) | Категория клиента |
| operation_type | VARCHAR(30) | NOT NULL, CHECK (operation_type IN ('TRANSFER', 'PAYMENT', 'CASH_WITHDRAWAL', 'CARD_SERVICE', 'FX_TRANSFER')) | Тип операции |
| calculation_type | VARCHAR(30) | NOT NULL, CHECK (calculation_type IN ('FIXED', 'PERCENT', 'FIXED_PLUS_PERCENT')) | Тип расчёта комиссии |
| fixed_amount | NUMERIC(15,2) | CHECK (fixed_amount >= 0) | Фиксированная сумма комиссии |
| percentage | NUMERIC(7,4) | CHECK (percentage >= 0 AND percentage <= 100) | Процент комиссии |
| min_amount | NUMERIC(15,2) | CHECK (min_amount >= 0) | Минимальная сумма комиссии |
| max_amount | NUMERIC(15,2) | CHECK (max_amount >= 0) | Максимальная сумма комиссии |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| valid_from | DATE | NOT NULL | Дата начала действия тарифа |
| valid_to | DATE | CHECK (valid_to >= valid_from) | Дата окончания действия тарифа |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')) | Статус тарифа |

При изменении условий тарифа создаётся новая запись с новым периодом действия `valid_from` / `valid_to`.

#### Сущность `benefit`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| benefit_id | UUID | PK | Уникальный идентификатор льготы |
| client_id | UUID | FK, NOT NULL | Клиент |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| benefit_type | VARCHAR(30) | NOT NULL, CHECK (benefit_type IN ('PERCENT_DISCOUNT', 'FIXED_DISCOUNT', 'FREE_OPERATIONS')) | Тип льготы |
| discount_percent | NUMERIC(7,4) | CHECK (discount_percent >= 0 AND discount_percent <= 100) | Процент скидки |
| discount_amount | NUMERIC(15,2) | CHECK (discount_amount >= 0) | Фиксированная сумма скидки |
| free_operation_count | INTEGER | CHECK (free_operation_count >= 0) | Количество бесплатных операций |
| valid_from | DATE | NOT NULL | Дата начала действия |
| valid_to | DATE | CHECK (valid_to >= valid_from) | Дата окончания действия |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'INACTIVE', 'EXPIRED')) | Статус льготы |

#### Сущность `exchange_rate`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| exchange_rate_id | UUID | PK | Уникальный идентификатор курса |
| base_currency | VARCHAR(3) | NOT NULL | Код базовой валюты по стандарту ISO 4217 |
| quote_currency | VARCHAR(3) | NOT NULL | Код валюты котировки по стандарту ISO 4217 |
| rate | NUMERIC(18,8) | NOT NULL, CHECK (rate > 0) | Курс валют |
| rate_date | DATE | NOT NULL | Дата курса |
| source | VARCHAR(50) | NOT NULL | Источник курса |

#### Сущность `periodic_charge`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| periodic_charge_id | UUID | PK | Уникальный идентификатор периодического начисления |
| client_id | UUID | FK, NOT NULL | Клиент |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| operation_type | VARCHAR(30) | NOT NULL, CHECK (operation_type IN ('TRANSFER', 'PAYMENT', 'CASH_WITHDRAWAL', 'CARD_SERVICE', 'FX_TRANSFER')) | Тип операции |
| periodicity | VARCHAR(20) | NOT NULL, CHECK (periodicity IN ('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY')) | Периодичность |
| next_charge_date | DATE | NOT NULL | Дата следующего начисления |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('ACTIVE', 'PAUSED', 'CLOSED')) | Статус периодического начисления |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

#### Сущность `charge`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| charge_id | UUID | PK | Уникальный идентификатор начисления |
| billing_event_id | UUID | FK, UNIQUE | Исходное биллинговое событие |
| periodic_charge_id | UUID | FK | Периодическое начисление |
| tariff_id | UUID | FK, NOT NULL | Использованный тариф |
| benefit_id | UUID | FK | Применённая льгота |
| exchange_rate_id | UUID | FK | Использованный валютный курс |
| amount | NUMERIC(15,2) | NOT NULL, CHECK (amount >= 0) | Итоговая сумма начисления |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| discount_amount | NUMERIC(15,2) | NOT NULL, DEFAULT 0, CHECK (discount_amount >= 0) | Сумма применённой скидки |
| calculated_at | TIMESTAMPTZ | NOT NULL | Дата и время расчёта |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('CALCULATED', 'PAID', 'FAILED', 'REFUNDED')) | Статус начисления |

Источником начисления является либо `billing_event`, либо `periodic_charge`. Одновременное заполнение обоих идентификаторов запрещено ограничением целостности.

Для разовой денежной операции предварительный расчёт хранится в `billing_operation`. Запись `charge` создаётся только после получения статуса `COMPLETED` от системы денежных переводов. При `FAILED` или `CANCELLED` начисление не создаётся. Для периодических платежей `charge` создаётся при наступлении даты очередного начисления.

#### Сущность `debit_order`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| debit_order_id | UUID | PK | Уникальный идентификатор распоряжения |
| charge_id | UUID | FK, NOT NULL, UNIQUE | Начисление |
| account_id | UUID | FK, NOT NULL | Счёт списания |
| amount | NUMERIC(15,2) | NOT NULL, CHECK (amount > 0) | Сумма списания |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| purpose | VARCHAR(255) | NOT NULL | Назначение списания |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('CREATED', 'PROCESSING', 'PAID', 'FAILED')) | Статус распоряжения |
| attempt_count | INTEGER | NOT NULL, DEFAULT 0, CHECK (attempt_count >= 0) | Количество попыток списания |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |
| updated_at | TIMESTAMPTZ | CHECK (updated_at >= created_at) | Дата последнего изменения |

#### Сущность `adjustment`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| adjustment_id | UUID | PK | Уникальный идентификатор корректировки |
| charge_id | UUID | FK, NOT NULL | Начисление |
| amount | NUMERIC(15,2) | NOT NULL, CHECK (amount <> 0) | Сумма корректировки |
| reason | TEXT | NOT NULL | Причина корректировки |
| created_by | VARCHAR(100) | NOT NULL | Инициатор корректировки |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

#### Сущность `refund`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| refund_id | UUID | PK | Уникальный идентификатор возврата |
| charge_id | UUID | FK, NOT NULL | Начисление |
| amount | NUMERIC(15,2) | NOT NULL, CHECK (amount > 0) | Сумма возврата |
| reason | TEXT | NOT NULL | Причина возврата |
| status | VARCHAR(20) | NOT NULL, CHECK (status IN ('CREATED', 'PROCESSING', 'COMPLETED', 'FAILED')) | Статус возврата |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

---

#### Сущность `outbox_event`

Техническая таблица transactional outbox используется для надёжной асинхронной публикации событий в Kafka.

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| event_id | UUID | PK | Уникальный идентификатор события |
| charge_id | UUID | FK, NOT NULL | Начисление, по которому сформировано событие |
| client_id | UUID | FK, NOT NULL | Клиент, связанный с событием |
| refund_id | UUID | FK | Возврат, если событие связано с возвратом комиссии |
| event_type | VARCHAR(30) | NOT NULL, CHECK (event_type IN ('COMMISSION_PAID', 'COMMISSION_FAILED', 'COMMISSION_REFUNDED')) | Тип события |
| amount | NUMERIC(15,2) | NOT NULL, CHECK (amount >= 0) | Сумма комиссии или возврата |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| correlation_id | VARCHAR(100) | NOT NULL | Идентификатор сквозной трассировки |
| occurred_at | TIMESTAMPTZ | NOT NULL | Дата и время возникновения бизнес-события |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'NEW', CHECK (status IN ('NEW', 'PUBLISHED', 'FAILED')) | Статус публикации |
| attempt_count | INTEGER | NOT NULL, DEFAULT 0, CHECK (attempt_count >= 0) | Количество попыток публикации |
| created_at | TIMESTAMPTZ | NOT NULL | Дата создания записи |
| published_at | TIMESTAMPTZ | CHECK (published_at >= created_at) | Дата успешной публикации события |

Изменение итогового состояния начисления и создание записи `outbox_event` должны выполняться в одной транзакции PostgreSQL.

`Billing Worker / Event Publisher` выбирает записи со статусом `NEW`, публикует их в Kafka topic `billing.notification-events` и после успешной публикации переводит запись в статус `PUBLISHED`.

Повторная публикация одного события допускается. Система уведомлений выполняет дедупликацию по `event_id`.

---

## 3. DDL PostgreSQL

Скрипт создания схемы, таблиц, ограничений и индексов:

```sql
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
```

## 4. DML PostgreSQL

Пример наполнения схемы тестовыми данными:

```sql
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


INSERT INTO billing.billing_operation (
    operation_id,
    external_operation_id,
    idempotency_key,
    billing_event_id,
    client_id,
    account_id,
    status,
    billing_decision,
    decision_reason,
    commission_amount,
    commission_currency,
    charge_status,
    version,
    created_at,
    updated_at
) VALUES
(
    'billing-70001',
    'transfer-10001',
    'billing-12345',
    'f1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'COMPLETED',
    'APPROVED',
    NULL,
    150.00,
    'RUB',
    'PAID',
    2,
    '2026-08-15 10:00:01+03',
    '2026-08-15 10:00:04+03'
),
(
    'billing-70002',
    'transfer-10002',
    'billing-22345',
    'f2222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'COMPLETED',
    'APPROVED',
    NULL,
    40.00,
    'RUB',
    'PAID',
    2,
    '2026-08-15 11:00:01+03',
    '2026-08-15 11:00:04+03'
),
(
    'billing-70003',
    'transfer-10003',
    'billing-32345',
    'f3333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'COMPLETED',
    'APPROVED',
    NULL,
    90.13,
    'RUB',
    'PAID',
    2,
    '2026-08-15 12:00:01+03',
    '2026-08-15 12:00:04+03'
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

UPDATE billing.charge
SET status = 'REFUNDED'
WHERE charge_id = '77777777-7777-7777-7777-777777777772';


UPDATE billing.billing_operation
SET
    charge_status = 'REFUNDED',
    version = version + 1,
    updated_at = '2026-08-17 14:00:00+03'
WHERE operation_id = 'billing-70002';


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
    'f5555555-5555-5555-5555-555555555555',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'TRANSFER',
    7500.00,
    'RUB',
    '2026-08-15 14:00:00+03',
    'PAYMENT_PROCESSING',
    'PROCESSED',
    '2026-08-15 14:00:01+03'
);


INSERT INTO billing.billing_operation (
    operation_id,
    external_operation_id,
    idempotency_key,
    billing_event_id,
    client_id,
    account_id,
    status,
    billing_decision,
    decision_reason,
    commission_amount,
    commission_currency,
    charge_status,
    version,
    created_at,
    updated_at
) VALUES
(
    'billing-70005',
    'transfer-10005',
    'billing-52345',
    'f5555555-5555-5555-5555-555555555555',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'ERROR',
    'APPROVED',
    NULL,
    75.00,
    'RUB',
    'PAYMENT_ERROR',
    2,
    '2026-08-15 14:00:01+03',
    '2026-08-15 14:00:06+03'
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
    '77777777-7777-7777-7777-777777777775',
    'f5555555-5555-5555-5555-555555555555',
    NULL,
    'cccccccc-cccc-cccc-cccc-ccccccccccc1',
    NULL,
    NULL,
    75.00,
    'RUB',
    0.00,
    '2026-08-15 14:00:02+03',
    'FAILED'
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
    '66666666-6666-6666-6666-666666666665',
    '77777777-7777-7777-7777-777777777775',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    75.00,
    'RUB',
    'Комиссия за перевод',
    'FAILED',
    3,
    '2026-08-15 14:00:03+03',
    '2026-08-15 14:00:06+03'
);

INSERT INTO billing.outbox_event (
    event_id,
    charge_id,
    client_id,
    refund_id,
    event_type,
    amount,
    currency,
    correlation_id,
    occurred_at,
    status,
    attempt_count,
    created_at,
    published_at
) VALUES
(
    '88888888-8888-8888-8888-888888888881',
    '77777777-7777-7777-7777-777777777771',
    '11111111-1111-1111-1111-111111111111',
    NULL,
    'COMMISSION_PAID',
    150.00,
    'RUB',
    'transfer-10001',
    '2026-08-15 10:00:04+03',
    'PUBLISHED',
    1,
    '2026-08-15 10:00:04+03',
    '2026-08-15 10:00:05+03'
),
(
    '88888888-8888-8888-8888-888888888882',
    '77777777-7777-7777-7777-777777777772',
    '22222222-2222-2222-2222-222222222222',
    '44444444-4444-4444-4444-444444444441',
    'COMMISSION_REFUNDED',
    40.00,
    'RUB',
    'transfer-10002',
    '2026-08-17 14:00:00+03',
    'PUBLISHED',
    1,
    '2026-08-17 14:00:00+03',
    '2026-08-17 14:00:01+03'
),
(
    '88888888-8888-8888-8888-888888888883',
    '77777777-7777-7777-7777-777777777775',
    '11111111-1111-1111-1111-111111111111',
    NULL,
    'COMMISSION_FAILED',
    75.00,
    'RUB',
    'transfer-10005',
    '2026-08-15 14:00:06+03',
    'NEW',
    0,
    '2026-08-15 14:00:06+03',
    NULL
);
```

---

## 5. Модель MongoDB

Для хранения агрегированной истории обработки начисления используется коллекция `billing_history`.

Один документ коллекции содержит данные об одном начислении и связанных с ним этапах обработки.

### 5.1. Class Diagram

![MongoDB Class Diagram](bbs_mongodb_class_diagram.png)

Корневой объект `BillingHistory` содержит поля, типы которых соответствуют вложенным классам:

- `event : BillingEvent`;
- `tariff : Tariff`;
- `benefit : Benefit`;
- `calculation : Calculation`;
- `debit : Debit`;
- `adjustments : Adjustment[]`;
- `refunds : Refund[]`;
- `history : StatusHistory[]`.

### 5.2. JSON-объект

Пример документа коллекции `billing_history`, который валидируется приведённой ниже JSON Schema:

```json
{
  "chargeId": "77777777-7777-7777-7777-777777777772",
  "createdAt": "2026-08-15T11:00:02+03:00",
  "event": {
    "eventId": "f2222222-2222-2222-2222-222222222222",
    "operationType": "TRANSFER",
    "amount": 10000.0,
    "currency": "RUB",
    "operationAt": "2026-08-15T11:00:00+03:00",
    "sourceSystem": "PAYMENT_PROCESSING"
  },
  "tariff": {
    "tariffId": "cccccccc-cccc-cccc-cccc-ccccccccccc2",
    "name": "Перевод Premium",
    "calculationType": "PERCENT",
    "fixedAmount": null,
    "percentage": 0.5,
    "minAmount": 10.0,
    "maxAmount": 300.0
  },
  "benefit": {
    "benefitId": "dddddddd-dddd-dddd-dddd-ddddddddddd1",
    "benefitType": "PERCENT_DISCOUNT",
    "discountPercent": 20.0,
    "discountAmount": null,
    "freeOperationCount": null
  },
  "calculation": {
    "baseAmount": 50.0,
    "discountAmount": 10.0,
    "finalAmount": 40.0,
    "currency": "RUB",
    "calculatedAt": "2026-08-15T11:00:02+03:00"
  },
  "debit": {
    "debitOrderId": "66666666-6666-6666-6666-666666666662",
    "accountId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2",
    "amount": 40.0,
    "currency": "RUB",
    "status": "PAID",
    "attemptCount": 1
  },
  "adjustments": [],
  "refunds": [
    {
      "refundId": "44444444-4444-4444-4444-444444444441",
      "amount": 40.0,
      "reason": "Возврат комиссии по обращению клиента",
      "status": "COMPLETED",
      "createdAt": "2026-08-17T14:00:00+03:00"
    }
  ],
  "history": [
    {
      "status": "CALCULATED",
      "changedAt": "2026-08-15T11:00:02+03:00"
    },
    {
      "status": "PAID",
      "changedAt": "2026-08-15T11:00:04+03:00"
    },
    {
      "status": "REFUNDED",
      "changedAt": "2026-08-17T14:00:00+03:00"
    }
  ]
}
```

### 5.3. JSON Schema

Схема валидации документа по стандарту JSON Schema Draft 7:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BillingHistory",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "chargeId",
    "createdAt",
    "tariff",
    "calculation",
    "adjustments",
    "refunds",
    "history"
  ],
  "properties": {
    "chargeId": {
      "type": "string",
      "format": "uuid"
    },
    "createdAt": {
      "type": "string",
      "format": "date-time"
    },
    "event": {
      "type": [
        "object",
        "null"
      ],
      "additionalProperties": false,
      "required": [
        "eventId",
        "operationType",
        "amount",
        "currency",
        "operationAt",
        "sourceSystem"
      ],
      "properties": {
        "eventId": {
          "type": "string",
          "format": "uuid"
        },
        "operationType": {
          "type": "string",
          "enum": [
            "TRANSFER",
            "PAYMENT",
            "CASH_WITHDRAWAL",
            "CARD_SERVICE",
            "FX_TRANSFER"
          ]
        },
        "amount": {
          "type": "number",
          "exclusiveMinimum": 0
        },
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$",
          "description": "Код валюты по стандарту ISO 4217"
        },
        "operationAt": {
          "type": "string",
          "format": "date-time"
        },
        "sourceSystem": {
          "type": "string"
        }
      }
    },
    "tariff": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "tariffId",
        "name",
        "calculationType"
      ],
      "properties": {
        "tariffId": {
          "type": "string",
          "format": "uuid"
        },
        "name": {
          "type": "string"
        },
        "calculationType": {
          "type": "string",
          "enum": [
            "FIXED",
            "PERCENT",
            "FIXED_PLUS_PERCENT"
          ]
        },
        "fixedAmount": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0
        },
        "percentage": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0,
          "maximum": 100
        },
        "minAmount": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0
        },
        "maxAmount": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0
        }
      }
    },
    "benefit": {
      "type": [
        "object",
        "null"
      ],
      "additionalProperties": false,
      "required": [
        "benefitId",
        "benefitType"
      ],
      "properties": {
        "benefitId": {
          "type": "string",
          "format": "uuid"
        },
        "benefitType": {
          "type": "string",
          "enum": [
            "PERCENT_DISCOUNT",
            "FIXED_DISCOUNT",
            "FREE_OPERATIONS"
          ]
        },
        "discountPercent": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0,
          "maximum": 100
        },
        "discountAmount": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0
        },
        "freeOperationCount": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 0
        }
      }
    },
    "calculation": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "baseAmount",
        "discountAmount",
        "finalAmount",
        "currency",
        "calculatedAt"
      ],
      "properties": {
        "baseAmount": {
          "type": "number",
          "minimum": 0
        },
        "discountAmount": {
          "type": "number",
          "minimum": 0
        },
        "finalAmount": {
          "type": "number",
          "minimum": 0
        },
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$",
          "description": "Код валюты по стандарту ISO 4217"
        },
        "calculatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "debit": {
      "type": [
        "object",
        "null"
      ],
      "additionalProperties": false,
      "required": [
        "debitOrderId",
        "accountId",
        "amount",
        "currency",
        "status",
        "attemptCount"
      ],
      "properties": {
        "debitOrderId": {
          "type": "string",
          "format": "uuid"
        },
        "accountId": {
          "type": "string",
          "format": "uuid"
        },
        "amount": {
          "type": "number",
          "exclusiveMinimum": 0
        },
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$",
          "description": "Код валюты по стандарту ISO 4217"
        },
        "status": {
          "type": "string",
          "enum": [
            "CREATED",
            "PROCESSING",
            "PAID",
            "FAILED"
          ]
        },
        "attemptCount": {
          "type": "integer",
          "minimum": 0
        }
      }
    },
    "adjustments": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "adjustmentId",
          "amount",
          "reason",
          "createdAt"
        ],
        "properties": {
          "adjustmentId": {
            "type": "string",
            "format": "uuid"
          },
          "amount": {
            "type": "number",
            "not": {
              "const": 0
            }
          },
          "reason": {
            "type": "string"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      }
    },
    "refunds": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "refundId",
          "amount",
          "reason",
          "status",
          "createdAt"
        ],
        "properties": {
          "refundId": {
            "type": "string",
            "format": "uuid"
          },
          "amount": {
            "type": "number",
            "exclusiveMinimum": 0
          },
          "reason": {
            "type": "string"
          },
          "status": {
            "type": "string",
            "enum": [
              "CREATED",
              "PROCESSING",
              "COMPLETED",
              "FAILED"
            ]
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      }
    },
    "history": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "status",
          "changedAt"
        ],
        "properties": {
          "status": {
            "type": "string",
            "enum": [
              "CALCULATED",
              "PAID",
              "FAILED",
              "REFUNDED"
            ]
          },
          "changedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      }
    }
  }
}
```

---

## 6. Описание значимости артефакта

| Раздел | Содержание |
|---|---|
| **Процесс и контекст использования** | Артефакт используется на этапе проектирования Banking Billing System при определении структуры хранения и взаимосвязей данных. Концептуальная модель применяется для согласования бизнес-сущностей и связей предметной области, логическая/физическая модель — для проектирования PostgreSQL, а Class Diagram и JSON Schema — для проектирования структуры документов MongoDB. |
| **Цель создания** | Определить и зафиксировать модель данных Banking Billing System, необходимую для хранения клиентов, счетов, банковских продуктов, биллинговых событий, тарифов, льгот, начислений, списаний, корректировок, возвратов, состояния REST-операций, событий transactional outbox и истории обработки начислений. |
| **Что становится определено** | Зафиксированы бизнес-сущности и связи между ними, состав таблиц PostgreSQL, включая технические таблицы `billing_operation` и `outbox_event`, типы данных, первичные и внешние ключи, ограничения целостности, структура MongoDB-документа, правила его валидации, а также DDL- и DML-скрипты PostgreSQL. |
| **Пользователи артефакта** | Системный аналитик использует модель для согласования структуры данных и бизнес-логики. Backend-разработчики используют её при реализации слоя хранения и бизнес-операций. DBA использует DDL для создания и сопровождения схемы PostgreSQL. Тестировщики используют модель, ограничения и тестовые данные для подготовки проверок целостности и интеграционных сценариев. |
| **Использование в дальнейшем** | На основании модели могут быть созданы миграции БД, репозитории и DAO, реализованы операции расчёта и списания комиссий, подготовлены API и интеграционные тесты. Модель также используется при анализе изменений требований и расширении Banking Billing System. |
| **Последствия отсутствия** | Без согласованной модели данных возможны неоднозначность хранения бизнес-сущностей, дублирование данных, нарушение ссылочной целостности, ошибки при выборе тарифов и расчёте начислений, а также увеличение времени разработки из-за различного понимания структуры данных участниками команды. |
