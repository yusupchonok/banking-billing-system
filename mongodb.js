use billing;

db.createCollection("billing_history", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "chargeId",
        "createdAt",
        "tariff",
        "calculation",
        "adjustments",
        "refunds",
        "history"
      ],
      additionalProperties: false,
      properties: {
        _id: {},
        chargeId: {
          bsonType: "string"
        },
        createdAt: {
          bsonType: "date"
        },
        event: {
          bsonType: ["object", "null"],
          additionalProperties: false,
          required: [
            "eventId",
            "operationType",
            "amount",
            "currency",
            "operationAt",
            "sourceSystem"
          ],
          properties: {
            eventId: { bsonType: "string" },
            operationType: { bsonType: "string" },
            amount: { bsonType: ["double", "decimal", "int", "long"] },
            currency: { bsonType: "string" },
            operationAt: { bsonType: "date" },
            sourceSystem: { bsonType: "string" }
          }
        },
        tariff: {
          bsonType: "object",
          additionalProperties: false,
          required: [
            "tariffId",
            "name",
            "calculationType"
          ],
          properties: {
            tariffId: { bsonType: "string" },
            name: { bsonType: "string" },
            calculationType: { bsonType: "string" },
            fixedAmount: { bsonType: ["double", "decimal", "int", "long", "null"] },
            percentage: { bsonType: ["double", "decimal", "int", "long", "null"] },
            minAmount: { bsonType: ["double", "decimal", "int", "long", "null"] },
            maxAmount: { bsonType: ["double", "decimal", "int", "long", "null"] }
          }
        },
        benefit: {
          bsonType: ["object", "null"],
          additionalProperties: false,
          required: [
            "benefitId",
            "benefitType"
          ],
          properties: {
            benefitId: { bsonType: "string" },
            benefitType: { bsonType: "string" },
            discountPercent: { bsonType: ["double", "decimal", "int", "long", "null"] },
            discountAmount: { bsonType: ["double", "decimal", "int", "long", "null"] }
          }
        },
        calculation: {
          bsonType: "object",
          additionalProperties: false,
          required: [
            "baseAmount",
            "discountAmount",
            "finalAmount",
            "currency",
            "calculatedAt"
          ],
          properties: {
            baseAmount: { bsonType: ["double", "decimal", "int", "long"] },
            discountAmount: { bsonType: ["double", "decimal", "int", "long"] },
            finalAmount: { bsonType: ["double", "decimal", "int", "long"] },
            currency: { bsonType: "string" },
            calculatedAt: { bsonType: "date" }
          }
        },
        debit: {
          bsonType: ["object", "null"],
          additionalProperties: false,
          required: [
            "debitOrderId",
            "accountId",
            "amount",
            "currency",
            "status",
            "attemptCount"
          ],
          properties: {
            debitOrderId: { bsonType: "string" },
            accountId: { bsonType: "string" },
            amount: { bsonType: ["double", "decimal", "int", "long"] },
            currency: { bsonType: "string" },
            status: { bsonType: "string" },
            attemptCount: { bsonType: ["int", "long"] }
          }
        },
        adjustments: {
          bsonType: "array",
          items: {
            bsonType: "object",
            additionalProperties: false,
            required: [
              "adjustmentId",
              "amount",
              "reason",
              "createdAt"
            ],
            properties: {
              adjustmentId: { bsonType: "string" },
              amount: { bsonType: ["double", "decimal", "int", "long"] },
              reason: { bsonType: "string" },
              createdAt: { bsonType: "date" }
            }
          }
        },
        refunds: {
          bsonType: "array",
          items: {
            bsonType: "object",
            additionalProperties: false,
            required: [
              "refundId",
              "amount",
              "reason",
              "status",
              "createdAt"
            ],
            properties: {
              refundId: { bsonType: "string" },
              amount: { bsonType: ["double", "decimal", "int", "long"] },
              reason: { bsonType: "string" },
              status: { bsonType: "string" },
              createdAt: { bsonType: "date" }
            }
          }
        },
        history: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            additionalProperties: false,
            required: [
              "status",
              "changedAt"
            ],
            properties: {
              status: { bsonType: "string" },
              changedAt: { bsonType: "date" }
            }
          }
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

db.billing_history.createIndex(
  { chargeId: 1 },
  { unique: true }
);

db.billing_history.insertOne({
  chargeId: "77777777-7777-7777-7777-777777777772",
  createdAt: ISODate("2026-08-15T08:00:02Z"),

  event: {
    eventId: "f2222222-2222-2222-2222-222222222222",
    operationType: "TRANSFER",
    amount: 10000.00,
    currency: "RUB",
    operationAt: ISODate("2026-08-15T08:00:00Z"),
    sourceSystem: "PAYMENT_PROCESSING"
  },

  tariff: {
    tariffId: "cccccccc-cccc-cccc-cccc-ccccccccccc2",
    name: "Перевод Premium",
    calculationType: "PERCENT",
    fixedAmount: null,
    percentage: 0.5,
    minAmount: 10.00,
    maxAmount: 300.00
  },

  benefit: {
    benefitId: "dddddddd-dddd-dddd-dddd-ddddddddddd1",
    benefitType: "DISCOUNT_PERCENT",
    discountPercent: 20.0,
    discountAmount: null
  },

  calculation: {
    baseAmount: 50.00,
    discountAmount: 10.00,
    finalAmount: 40.00,
    currency: "RUB",
    calculatedAt: ISODate("2026-08-15T08:00:02Z")
  },

  debit: {
    debitOrderId: "66666666-6666-6666-6666-666666666662",
    accountId: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2",
    amount: 40.00,
    currency: "RUB",
    status: "PAID",
    attemptCount: 1
  },

  adjustments: [],

  refunds: [
    {
      refundId: "44444444-4444-4444-4444-444444444441",
      amount: 40.00,
      reason: "Возврат комиссии по обращению клиента",
      status: "COMPLETED",
      createdAt: ISODate("2026-08-17T11:00:00Z")
    }
  ],

  history: [
    {
      status: "CALCULATED",
      changedAt: ISODate("2026-08-15T08:00:02Z")
    },
    {
      status: "PAID",
      changedAt: ISODate("2026-08-15T08:00:04Z")
    },
    {
      status: "REFUNDED",
      changedAt: ISODate("2026-08-17T11:00:00Z")
    }
  ]
});
