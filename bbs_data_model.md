# Модель данных Banking Billing System

## Концептуальная модель данных в нотации Чена

![Концептуальная модель данных](bbs_chen_notation.svg)

---

## Логическая/физическая модель данных в нотации Мартина

![Логическая/физическая модель данных](bbs_martin_notation.svg)

 
### Табличная часть

#### Сущность `client`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| client_id | UUID | PK | Уникальный идентификатор клиента |
| category | client_category_enum | NOT NULL | Категория клиента: `STANDARD`, `PREMIUM` |
| status | client_status_enum | NOT NULL | Статус клиента: `ACTIVE`, `BLOCKED`, `CLOSED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `account`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| account_id | UUID | PK | Уникальный идентификатор счёта |
| client_id | UUID | FK, NOT NULL | Ссылка на клиента |
| account_number | VARCHAR(34) | NOT NULL, UNIQUE | Номер банковского счёта |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| status | account_status_enum | NOT NULL | Статус счёта: `ACTIVE`, `BLOCKED`, `CLOSED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания счёта |

#### Сущность `bank_product`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| product_id | UUID | PK | Уникальный идентификатор банковского продукта |
| name | VARCHAR(100) | NOT NULL | Название продукта. Не является уникальным |
| product_type | product_type_enum | NOT NULL | Тип продукта: `ACCOUNT`, `CARD`, `DEPOSIT`, `LOAN` |
| status | product_status_enum | NOT NULL | Статус продукта: `ACTIVE`, `INACTIVE`, `ARCHIVED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `billing_event`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| event_id | UUID | PK | Уникальный идентификатор биллингового события |
| account_id | UUID | FK, NOT NULL | Счёт, связанный с операцией |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| operation_type | operation_type_enum | NOT NULL | Тип операции: `TRANSFER`, `PAYMENT`, `CASH_WITHDRAWAL`, `CARD_SERVICE`, `FX_TRANSFER` |
| operation_amount | NUMERIC(15,2) | NOT NULL, CHECK > 0 | Сумма операции |
| operation_currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| operation_at | TIMESTAMPTZ | NOT NULL | Дата и время операции |
| source_system | VARCHAR(50) | NOT NULL | Система-источник события |
| status | billing_event_status_enum | NOT NULL | Статус: `NEW`, `PROCESSED`, `FAILED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания записи |

#### Сущность `tariff`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| tariff_id | UUID | PK | Уникальный идентификатор тарифа |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| name | VARCHAR(100) | NOT NULL | Название тарифа. Не является уникальным |
| client_category | client_category_enum | NULL | Категория клиента: `STANDARD`, `PREMIUM` |
| operation_type | operation_type_enum | NOT NULL | Тип операции |
| calculation_type | calculation_type_enum | NOT NULL | Тип расчёта: `FIXED`, `PERCENT`, `FIXED_PLUS_PERCENT` |
| fixed_amount | NUMERIC(15,2) | NULL, CHECK >= 0 | Фиксированная часть комиссии |
| percentage | NUMERIC(7,4) | NULL, CHECK 0–100 | Процент комиссии |
| min_amount | NUMERIC(15,2) | NULL, CHECK >= 0 | Минимальная сумма комиссии |
| max_amount | NUMERIC(15,2) | NULL, CHECK >= min_amount | Максимальная сумма комиссии |
| currency | VARCHAR(3) | NOT NULL | Код валюты по стандарту ISO 4217 |
| valid_from | DATE | NOT NULL | Дата начала действия тарифа |
| valid_to | DATE | NULL, CHECK >= valid_from | Дата окончания действия тарифа |
| status | tariff_status_enum | NOT NULL | Статус: `ACTIVE`, `INACTIVE`, `ARCHIVED` |

При изменении условий тарифа создаётся новая запись с новым периодом действия valid_from / valid_to.

#### Сущность `benefit`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| benefit_id | UUID | PK | Уникальный идентификатор льготы |
| client_id | UUID | FK, NOT NULL | Клиент |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| benefit_type | benefit_type_enum | NOT NULL | Тип льготы: `PERCENT_DISCOUNT`, `FIXED_DISCOUNT`, `FREE_OPERATIONS` |
| discount_percent | NUMERIC(7,4) | NULL, CHECK 0–100 | Процент скидки |
| discount_amount | NUMERIC(15,2) | NULL, CHECK >= 0 | Фиксированная сумма скидки |
| free_operation_count | INTEGER | NULL, CHECK >= 0 | Количество бесплатных операций |
| valid_from | DATE | NOT NULL | Дата начала действия |
| valid_to | DATE | NULL, CHECK >= valid_from | Дата окончания действия |
| status | benefit_status_enum | NOT NULL | Статус: `ACTIVE`, `INACTIVE`, `EXPIRED` |

#### Сущность `exchange_rate`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| exchange_rate_id | UUID | PK | Уникальный идентификатор курса |
| base_currency | VARCHAR(3) | NOT NULL | Базовая валюта по ISO 4217 |
| quote_currency | VARCHAR(3) | NOT NULL | Валюта котировки по ISO 4217 |
| rate | NUMERIC(18,8) | NOT NULL, CHECK > 0 | Курс валют |
| rate_date | DATE | NOT NULL | Дата курса |
| source | VARCHAR(50) | NOT NULL | Источник курса |

#### Сущность `periodic_charge`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| periodic_charge_id | UUID | PK | Уникальный идентификатор периодического начисления |
| client_id | UUID | FK, NOT NULL | Клиент |
| product_id | UUID | FK, NOT NULL | Банковский продукт |
| operation_type | operation_type_enum | NOT NULL | Тип операции |
| periodicity | periodicity_enum | NOT NULL | Периодичность: `DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY` |
| next_charge_date | DATE | NOT NULL | Дата следующего начисления |
| status | periodic_charge_status_enum | NOT NULL | Статус: `ACTIVE`, `PAUSED`, `CLOSED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

#### Сущность `charge`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| charge_id | UUID | PK | Уникальный идентификатор начисления |
| billing_event_id | UUID | FK, UNIQUE, NULL | Исходное биллинговое событие |
| periodic_charge_id | UUID | FK, NULL | Периодическое начисление |
| tariff_id | UUID | FK, NOT NULL | Использованный тариф |
| benefit_id | UUID | FK, NULL | Применённая льгота |
| exchange_rate_id | UUID | FK, NULL | Использованный валютный курс |
| amount | NUMERIC(15,2) | NOT NULL, CHECK >= 0 | Итоговая сумма начисления |
| currency | VARCHAR(3) | NOT NULL | Код валюты по ISO 4217 |
| discount_amount | NUMERIC(15,2) | NOT NULL, DEFAULT 0, CHECK >= 0 | Сумма применённой скидки |
| calculated_at | TIMESTAMPTZ | NOT NULL | Дата и время расчёта |
| status | charge_status_enum | NOT NULL | Статус: `CALCULATED`, `PAID`, `FAILED`, `REFUNDED` |

Источником начисления является либо `billing_event`, либо `periodic_charge`. Одновременное заполнение обоих идентификаторов запрещено ограничением целостности.

#### Сущность `debit_order`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| debit_order_id | UUID | PK | Уникальный идентификатор распоряжения |
| charge_id | UUID | FK, NOT NULL, UNIQUE | Начисление |
| account_id | UUID | FK, NOT NULL | Счёт списания |
| amount | NUMERIC(15,2) | NOT NULL, CHECK > 0 | Сумма списания |
| currency | VARCHAR(3) | NOT NULL | Код валюты по ISO 4217 |
| purpose | VARCHAR(255) | NOT NULL | Назначение списания |
| status | debit_order_status_enum | NOT NULL | Статус: `CREATED`, `PROCESSING`, `PAID`, `FAILED` |
| attempt_count | INTEGER | NOT NULL, DEFAULT 0, CHECK >= 0 | Количество попыток списания |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |
| updated_at | TIMESTAMPTZ | NULL, CHECK >= created_at | Дата последнего изменения |

#### Сущность `adjustment`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| adjustment_id | UUID | PK | Уникальный идентификатор корректировки |
| charge_id | UUID | FK, NOT NULL | Начисление |
| amount | NUMERIC(15,2) | NOT NULL, CHECK <> 0 | Сумма корректировки |
| reason | TEXT | NOT NULL | Причина корректировки |
| created_by | VARCHAR(100) | NOT NULL | Инициатор корректировки |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

#### Сущность `refund`

| Атрибут | Тип данных | Ограничения | Описание |
|---|---|---|---|
| refund_id | UUID | PK | Уникальный идентификатор возврата |
| charge_id | UUID | FK, NOT NULL | Начисление |
| amount | NUMERIC(15,2) | NOT NULL, CHECK > 0 | Сумма возврата |
| reason | TEXT | NOT NULL | Причина возврата |
| status | refund_status_enum | NOT NULL | Статус: `CREATED`, `PROCESSING`, `COMPLETED`, `FAILED` |
| created_at | TIMESTAMPTZ | NOT NULL | Дата и время создания |

---

## DDL-скрипт PostgreSQL

Скрипт создания схемы, таблиц, ограничений, типов и индексов:

[postgresql_ddl.sql](postgresql_ddl.sql)

## DML-скрипт PostgreSQL

Скрипт наполнения схемы тестовыми данными:

[postgresql_dml.sql](postgresql_dml.sql)

---

# Модель MongoDB

Для хранения агрегированной истории обработки начисления используется коллекция `billing_history`.

Один документ коллекции содержит данные об одном начислении и связанных с ним этапах обработки.

## Class Diagram

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

## JSON-объект

Пример конечного документа MongoDB:

[JSONobject.json](JSONobject.json)

## JSON Schema

Схема валидации документа по стандарту JSON Schema Draft 7:

[JSONschema.json](JSONschema.json)

---

# Описание значимости артефакта

| Раздел | Содержание |
|---|---|
| **Процесс и контекст использования** | Артефакт используется на этапе проектирования Banking Billing System при определении структуры хранения и взаимосвязей данных. Концептуальная модель применяется для согласования бизнес-сущностей и связей предметной области, логическая/физическая модель — для проектирования PostgreSQL, а Class Diagram и JSON Schema — для проектирования структуры документов MongoDB. |
| **Цель создания** | Определить и зафиксировать модель данных Banking Billing System, необходимую для хранения клиентов, счетов, банковских продуктов, биллинговых событий, тарифов, льгот, начислений, списаний, корректировок, возвратов и истории обработки начислений. |
| **Что становится определено** | Зафиксированы бизнес-сущности и связи между ними, состав таблиц PostgreSQL, типы данных, первичные и внешние ключи, ограничения целостности, структура MongoDB-документа, правила его валидации, а также DDL- и DML-скрипты PostgreSQL. |
| **Пользователи артефакта** | Системный аналитик использует модель для согласования структуры данных и бизнес-логики. Backend-разработчики используют её при реализации слоя хранения и бизнес-операций. DBA использует DDL для создания и сопровождения схемы PostgreSQL. Тестировщики используют модель, ограничения и тестовые данные для подготовки проверок целостности и интеграционных сценариев. |
| **Использование в дальнейшем** | На основании модели могут быть созданы миграции БД, репозитории и DAO, реализованы операции расчёта и списания комиссий, подготовлены API и интеграционные тесты. Модель также используется при анализе изменений требований и расширении Banking Billing System. |
| **Последствия отсутствия** | Без согласованной модели данных возможны неоднозначность хранения бизнес-сущностей, дублирование данных, нарушение ссылочной целостности, ошибки при выборе тарифов и расчёте начислений, а также увеличение времени разработки из-за различного понимания структуры данных участниками команды. |
