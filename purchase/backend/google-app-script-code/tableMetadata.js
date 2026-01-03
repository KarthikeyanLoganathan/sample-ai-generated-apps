const TABLE_NAMES_TO_INDICES = Object.freeze({
    manufacturers: 1,
    vendors: 2,
    materials: 3,
    manufacturer_materials: 4,
    vendor_price_lists: 5,
    purchase_orders: 6,
    purchase_order_items: 7,
    purchase_order_payments: 8,
    basket_headers: 9,
    basket_items: 10,
    basket_vendors: 11,
    basket_vendor_items: 12,
});

const TABLE_INDICES_TO_NAMES = (function () {
    let result = {};
    for (const [name, index] of Object.entries(TABLE_NAMES_TO_INDICES)) {
        result[String(index)] = name;
    }
    return Object.freeze(result);
})();

const DATA_TYPES = Object.freeze({
    UUID: "dc134eea-29d5-4af6-9bcc-e45076770d9a",//different different values to be used for comparison
    TABLE_IDENTIFIER_INDEX: 1, //different different values to be used for comparison
    ID: 2,//different different values to be used for comparison
    INTEGER: 3,//different different values to be used for comparison
    AMOUNT: 4.5,//different different values to be used for comparison
    QUANTITY: 5.5,//different different values to be used for comparison
    DOUBLE: 6.5,//different different values to be used for comparison
    NAME: "NAME",//different different values to be used for comparison
    STRING: "String",//different different values to be used for comparison
    CURRENCY: "Currency",//different different values to be used for comparison
    PERCENT: 0.1,//different different values to be used for comparison
    DESCRIPTION: "Description",//different different values to be used for comparison
    TIME_STAMP: new Date(),//different different values to be used for comparison
    BOOLEAN: true,//different different values to be used for comparison
    CHANGE_MODE: "I",//different different values to be used for comparison
});

const TABLE_DEFINITIONS = Object.freeze({
    manufacturers: Object.freeze({
        NAME: "manufacturers",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    }),
    vendors: Object.freeze({
        NAME: "vendors",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            address: DATA_TYPES.STRING,
            geo_location: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    }),
    materials: Object.freeze({
        NAME: "materials",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            unit_of_measure: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    }),
    manufacturer_materials: Object.freeze({
        NAME: "manufacturer_materials",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            manufacturer_uuid: DATA_TYPES.UUID,
            material_uuid: DATA_TYPES.UUID,
            model: DATA_TYPES.STRING,
            selling_lot_size: DATA_TYPES.QUANTITY,
            max_retail_price: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            manufacturer_name: '=ARRAYFORMULA({"manufacturer_name"; IF(B2:B="", "", IFERROR(VLOOKUP(B2:B, manufacturers!A:C, 3, FALSE), "Not Found"))})',
            material_name:
                '=ARRAYFORMULA({"material_name"; IF(C2:C="", "", IFERROR(VLOOKUP(C2:C, materials!A:C, 3, FALSE), "Not Found"))})',
            unit_of_measure:
                '=ARRAYFORMULA({"unit_of_measure"; IF(C2:C="", "", IFERROR(VLOOKUP(C2:C, materials!A:E, 5, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'manufacturer_uuid',
                targetTable: 'manufacturers',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'material_uuid',
                targetTable: 'materials',
                targetColumn: 'uuid'
            })
        ]),
    }),
    vendor_price_lists: Object.freeze({
        NAME: "vendor_price_lists",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            manufacturer_material_uuid: DATA_TYPES.UUID,
            vendor_uuid: DATA_TYPES.UUID,
            rate: DATA_TYPES.AMOUNT,
            rate_before_tax: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            tax_percent: DATA_TYPES.PERCENT,
            tax_amount: DATA_TYPES.DOUBLE,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_name:
                '=ARRAYFORMULA({"vendor_name"; IF(C2:C="", "", IFERROR(VLOOKUP(C2:C, vendors!A:C, 3, FALSE), "Not Found"))})',
            manufacturer_name: '=ARRAYFORMULA({"manufacturer_name"; IF(B2:B="", "", IFERROR(VLOOKUP(B2:B, manufacturer_materials!A:K, 9, FALSE), "Not Found"))})',
            material_name: '=ARRAYFORMULA({"material_name"; IF(B2:B="", "", IFERROR(VLOOKUP(B2:B, manufacturer_materials!A:K, 10, FALSE), "Not Found"))})',
            model: '=ARRAYFORMULA({"model"; IF(B2:B="", "", IFERROR(VLOOKUP(B2:B, manufacturer_materials!A:K, 4, FALSE), "Not Found"))})',
            unit_of_measure: '=ARRAYFORMULA({"unit_of_measure"; IF(B2:B="", "", IFERROR(VLOOKUP(B2:B, manufacturer_materials!A:K, 11, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'manufacturer_material_uuid',
                targetTable: 'manufacturer_materials',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'vendor_uuid',
                targetTable: 'vendors',
                targetColumn: 'uuid'
            })
        ]),
    }),
    purchase_orders: Object.freeze({
        NAME: "purchase_orders",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            vendor_uuid: DATA_TYPES.UUID,
            date: DATA_TYPES.TIME_STAMP,
            base_price: DATA_TYPES.AMOUNT,
            tax_amount: DATA_TYPES.AMOUNT,
            total_amount: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            order_date: DATA_TYPES.TIME_STAMP,
            expected_delivery_date: DATA_TYPES.TIME_STAMP,
            amount_paid: DATA_TYPES.AMOUNT,
            amount_balance: DATA_TYPES.AMOUNT,
            completed: DATA_TYPES.BOOLEAN,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_name:
                '=ARRAYFORMULA({"vendor_name"; IF(C2:C="", "", IFERROR(VLOOKUP(C2:C, vendors!A:C, 3, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'vendor_uuid',
                targetTable: 'vendors',
                targetColumn: 'uuid'
            })
        ]),
    }),
    purchase_order_items: Object.freeze({
        NAME: "purchase_order_items",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            purchase_order_uuid: DATA_TYPES.UUID,
            manufacturer_material_uuid: DATA_TYPES.UUID,
            material_uuid: DATA_TYPES.UUID,
            model: DATA_TYPES.STRING,
            quantity: DATA_TYPES.QUANTITY,
            rate: DATA_TYPES.AMOUNT,
            rate_before_tax: DATA_TYPES.AMOUNT,
            base_price: DATA_TYPES.AMOUNT,
            tax_percent: DATA_TYPES.PERCENT,
            tax_amount: DATA_TYPES.AMOUNT,
            total_amount: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            material_name:
                '=ARRAYFORMULA({"material_name"; IF(D2:D="", "", IFERROR(VLOOKUP(D2:D, materials!A:C, 3, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'purchase_order_uuid',
                targetTable: 'purchase_orders',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'manufacturer_material_uuid',
                targetTable: 'manufacturer_materials',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'material_uuid',
                targetTable: 'materials',
                targetColumn: 'uuid'
            })
        ]),
    }),
    purchase_order_payments: Object.freeze({
        NAME: "purchase_order_payments",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            purchase_order_uuid: DATA_TYPES.UUID,
            date: DATA_TYPES.TIME_STAMP,
            amount: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            upi_ref_number: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'purchase_order_uuid',
                targetTable: 'purchase_orders',
                targetColumn: 'uuid'
            })
        ]),
    }),
    basket_headers: Object.freeze({
        NAME: "basket_headers",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            date: DATA_TYPES.TIME_STAMP,
            description: DATA_TYPES.DESCRIPTION,
            expected_delivery_date: DATA_TYPES.TIME_STAMP,
            total_price: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            number_of_items: DATA_TYPES.INTEGER,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    }),
    basket_items: Object.freeze({
        NAME: "basket_items",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            basket_uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            manufacturer_material_uuid: DATA_TYPES.UUID,
            material_uuid: DATA_TYPES.UUID,
            model: DATA_TYPES.STRING,
            manufacturer_uuid: DATA_TYPES.UUID,
            quantity: DATA_TYPES.QUANTITY,
            unit_of_measure: DATA_TYPES.STRING,
            max_retail_price: DATA_TYPES.AMOUNT,
            price: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            manufacturer_name:
                '=ARRAYFORMULA({"manufacturer_name"; IF(G2:G="", "", IFERROR(VLOOKUP(G2:G, manufacturers!A:C, 3, FALSE), "Not Found"))})',
            material_name:
                '=ARRAYFORMULA({"material_name"; IF(E2:E="", "", IFERROR(VLOOKUP(E2:E, materials!A:C, 3, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'basket_uuid',
                targetTable: 'basket_headers',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'manufacturer_material_uuid',
                targetTable: 'manufacturer_materials',
                targetColumn: 'uuid'
            })
        ]),
    }),
    basket_vendors: Object.freeze({
        NAME: "basket_vendors",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            basket_uuid: DATA_TYPES.UUID,
            vendor_uuid: DATA_TYPES.UUID,
            date: DATA_TYPES.TIME_STAMP,
            expected_delivery_date: DATA_TYPES.TIME_STAMP,
            base_price: DATA_TYPES.AMOUNT,
            tax_amount: DATA_TYPES.AMOUNT,
            total_amount: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            number_of_available_items: DATA_TYPES.INTEGER,
            number_of_unavailable_items: DATA_TYPES.INTEGER,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_name:
                '=ARRAYFORMULA({"vendor_name"; IF(D2:D="", "", IFERROR(VLOOKUP(D2:D, vendors!A:C, 3, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'basket_uuid',
                targetTable: 'basket_headers',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'vendor_uuid',
                targetTable: 'vendors',
                targetColumn: 'uuid'
            })
        ]),
    }),
    basket_vendor_items: Object.freeze({
        NAME: "basket_vendor_items",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            basket_vendor_uuid: DATA_TYPES.UUID,
            basket_uuid: DATA_TYPES.UUID,
            basket_item_uuid: DATA_TYPES.UUID,
            vendor_price_list_uuid: DATA_TYPES.UUID,
            item_available_with_vendor: DATA_TYPES.BOOLEAN,
            manufacturer_material_uuid: DATA_TYPES.UUID,
            material_uuid: DATA_TYPES.UUID,
            model: DATA_TYPES.STRING,
            quantity: DATA_TYPES.QUANTITY,
            max_retail_price: DATA_TYPES.AMOUNT,
            rate: DATA_TYPES.AMOUNT,
            rate_before_tax: DATA_TYPES.AMOUNT,
            base_price: DATA_TYPES.AMOUNT,
            tax_percent: DATA_TYPES.PERCENT,
            tax_amount: DATA_TYPES.AMOUNT,
            total_amount: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            material_name:
                '=ARRAYFORMULA({"material_name"; IF(H2:H="", "", IFERROR(VLOOKUP(H2:H, materials!A:C, 3, FALSE), "Not Found"))})',
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([
            Object.freeze({
                column: 'basket_vendor_uuid',
                targetTable: 'basket_vendors',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'basket_uuid',
                targetTable: 'basket_headers',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'basket_item_uuid',
                targetTable: 'basket_items',
                targetColumn: 'uuid'
            }),
            Object.freeze({
                column: 'vendor_price_list_uuid',
                targetTable: 'vendor_price_lists',
                targetColumn: 'uuid'
            })
        ]),
    }),
    change_log: Object.freeze({
        NAME: "change_log",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            table_index: DATA_TYPES.TABLE_IDENTIFIER_INDEX,
            table_key_uuid: DATA_TYPES.UUID,
            change_mode: DATA_TYPES.CHANGE_MODE,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    }),
    condensed_change_log: Object.freeze({
        NAME: "condensed_change_log",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            table_index: DATA_TYPES.TABLE_IDENTIFIER_INDEX,
            table_key_uuid: DATA_TYPES.UUID,
            change_mode: DATA_TYPES.CHANGE_MODE,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze([]),
    })
});

const TABLE_META_INFO = (function () {
    let result = {};
    const tableNames = [];
    for (const [tableName, def] of Object.entries(TABLE_DEFINITIONS)) {
        tableNames.push(tableName);
        const columnNames = Object.keys(def.COLUMNS);
        const lookupColumns = Object.keys(def.LOOKUP_COLUMNS);
        let colIndices = {};
        let columns = {}
        columnNames.forEach((colName, index) => {
            colIndices[colName] = index;
            columns[colName] = colName;
        });
        result[tableName] = Object.freeze({
            COLUMNS: Object.freeze(columns),
            COLUMN_NAMES: Object.freeze(columnNames),
            COLUMN_INDICES: Object.freeze(colIndices),
            COLUMN_COUNT: columnNames.length,
            LOOKUP_COLUMN_NAMES: Object.freeze(lookupColumns),
            LOOKUP_COLUMN_COUNT: lookupColumns.length,
            TOTAL_COLUMN_COUNT: columnNames.length + lookupColumns.length,
        });
    }
    result.TABLE_NAMES = Object.freeze(tableNames);
    return Object.freeze(result);
})();