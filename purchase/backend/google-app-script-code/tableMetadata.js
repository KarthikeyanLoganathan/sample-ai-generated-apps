const TABLE_NAMES_TO_INDICES = Object.freeze({
    unit_of_measures: 101,
    currencies: 102,
    manufacturers: 201,
    vendors: 202,
    materials: 203,
    manufacturer_materials: 204,
    vendor_price_lists: 205,
    purchase_orders: 301,
    purchase_order_items: 302,
    purchase_order_payments: 303,
    basket_headers: 311,
    basket_items: 312,
    quotations: 321,
    quotation_items: 322,
    projects: 251,
});

const TABLE_INDICES_TO_NAMES = (function () {
    let result = {};
    for (const [name, index] of Object.entries(TABLE_NAMES_TO_INDICES)) {
        result[String(index)] = name;
    }
    return Object.freeze(result);
})();

const DATA_TYPES = Object.freeze({
    UUID: "dc134eea-29d5-4af6-9bcc-e45076770d9a", //different different values to be used for comparison
    TABLE_IDENTIFIER_INDEX: 1, //different different values to be used for comparison
    ID: 2, //different different values to be used for comparison
    INTEGER: 3, //different different values to be used for comparison
    AMOUNT: 4.5, //different different values to be used for comparison
    QUANTITY: 5.5, //different different values to be used for comparison
    DOUBLE: 6.5, //different different values to be used for comparison
    NAME: "NAME", //different different values to be used for comparison
    STRING: "String", //different different values to be used for comparison
    CURRENCY: "Currency", //different different values to be used for comparison
    UNIT_OF_MEASURE: "unit_of_measure", //different different values to be used for comparison
    PERCENT: 0.1, //different different values to be used for comparison
    DESCRIPTION: "Description", //different different values to be used for comparison
    TIME_STAMP: new Date(), //different different values to be used for comparison
    BOOLEAN: true, //different different values to be used for comparison
    CHANGE_MODE: "I", //different different values to be used for comparison
    PHOTO: "photo_uuid", //different different values to be used for comparison
    WEBSITE: "website", //different different values to be used for comparison
    PHONE_NUMBER: "phone_number", //different different values to be used for comparison
    EMAIL_ADDRESS: "email_address", //different different values to be used for comparison
    ADDRESS: "address", //different different values to be used for comparison
    GEO_LOCATION: "geo_location", //different different values to be used for comparison
});

const TABLE_TYPES = Object.freeze({
    METADATA: "METADATA",
    CONFIGURATION_DATA: "CONFIGURATION_DATA",
    MASTER_DATA: "MASTER_DATA",
    TRANSACTION_DATA: "TRANSACTION_DATA",
    LOG: "LOG",
});

const TABLE_DEFINITIONS = Object.freeze({
    unit_of_measures: Object.freeze({
        NAME: "unit_of_measures",
        TYPE: TABLE_TYPES.CONFIGURATION_DATA,
        KEY_COLUMN: "name",
        COLUMNS: Object.freeze({
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            number_of_decimal_places: DATA_TYPES.INTEGER,
            is_default: DATA_TYPES.BOOLEAN,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    currencies: Object.freeze({
        NAME: "currencies",
        TYPE: TABLE_TYPES.CONFIGURATION_DATA,
        KEY_COLUMN: "name",
        COLUMNS: Object.freeze({
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            symbol: DATA_TYPES.STRING,
            number_of_decimal_places: DATA_TYPES.INTEGER,
            is_default: DATA_TYPES.BOOLEAN,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    manufacturers: Object.freeze({
        NAME: "manufacturers",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            address: DATA_TYPES.ADDRESS,
            phone_number: DATA_TYPES.PHONE_NUMBER,
            email_address: DATA_TYPES.EMAIL_ADDRESS,
            website: DATA_TYPES.WEBSITE,
            updated_at: DATA_TYPES.TIME_STAMP,
            photo_uuid: DATA_TYPES.UUID,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    vendors: Object.freeze({
        NAME: "vendors",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            address: DATA_TYPES.ADDRESS,
            geo_location: DATA_TYPES.GEO_LOCATION,
            phone_number: DATA_TYPES.PHONE_NUMBER,
            email_address: DATA_TYPES.EMAIL_ADDRESS,
            website: DATA_TYPES.WEBSITE,
            updated_at: DATA_TYPES.TIME_STAMP,
            photo_uuid: DATA_TYPES.UUID,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    materials: Object.freeze({
        NAME: "materials",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            unit_of_measure: DATA_TYPES.UNIT_OF_MEASURE,
            website: DATA_TYPES.WEBSITE,
            updated_at: DATA_TYPES.TIME_STAMP,
            photo_uuid: DATA_TYPES.UUID,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            unit_of_measure: Object.freeze({
                unit_of_measures: "name",
            }),
        }),
    }),
    manufacturer_materials: Object.freeze({
        NAME: "manufacturer_materials",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            manufacturer_uuid: DATA_TYPES.UUID,
            material_uuid: DATA_TYPES.UUID,
            model: DATA_TYPES.STRING,
            selling_lot_size: DATA_TYPES.QUANTITY,
            max_retail_price: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            website: DATA_TYPES.WEBSITE,
            part_number: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
            photo_uuid: DATA_TYPES.UUID,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            manufacturer_uuid: Object.freeze([
                "manufacturer_name"
            ]),
            material_uuid: Object.freeze([
                "material_name",
                "unit_of_measure"
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            currency: Object.freeze({
                currencies: "name",
            }),
            manufacturer_uuid: Object.freeze({
                manufacturers: "uuid"
            }),
            material_uuid: Object.freeze({
                materials: "uuid"
            }),
        }),
    }),
    vendor_price_lists: Object.freeze({
        NAME: "vendor_price_lists",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            manufacturer_material_uuid: DATA_TYPES.UUID,
            vendor_uuid: DATA_TYPES.UUID,
            rate: DATA_TYPES.AMOUNT,
            rate_before_tax: DATA_TYPES.AMOUNT,
            tax_amount: DATA_TYPES.DOUBLE,
            tax_percent: DATA_TYPES.PERCENT,
            currency: DATA_TYPES.CURRENCY,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_uuid: Object.freeze([
                "vendor_name"
            ]),
            manufacturer_material_uuid: Object.freeze([
                "manufacturer_name",
                "material_name",
                "model",
                "selling_lot_size",
                "max_retail_price",
                "unit_of_measure",
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            manufacturer_material_uuid: Object.freeze({
                manufacturer_materials: "uuid",
            }),
            vendor_uuid: Object.freeze({
                vendors: "uuid"
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    purchase_orders: Object.freeze({
        NAME: "purchase_orders",
        KEY_COLUMN: "uuid",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
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
            basket_uuid: DATA_TYPES.UUID,
            quotation_uuid: DATA_TYPES.UUID,
            project_uuid: DATA_TYPES.UUID,
            description: DATA_TYPES.DESCRIPTION,
            delivery_address: DATA_TYPES.ADDRESS,
            phone_number: DATA_TYPES.PHONE_NUMBER,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_uuid: Object.freeze([
                "vendor_name"
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            vendor_uuid: Object.freeze({
                vendors: "uuid"
            }),
            basket_uuid: Object.freeze({
                basket_headers: "uuid"
            }),
            quotation_uuid: Object.freeze({
                quotations: "uuid"
            }),
            project_uuid: Object.freeze({
                projects: "uuid"
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    purchase_order_items: Object.freeze({
        NAME: "purchase_order_items",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
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
            basket_item_uuid: DATA_TYPES.UUID,
            quotation_item_uuid: DATA_TYPES.UUID,
            unit_of_measure: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            material_uuid: Object.freeze(["material_name"]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            purchase_order_uuid: Object.freeze({
                purchase_orders: "uuid"
            }),
            manufacturer_material_uuid: Object.freeze({
                manufacturer_materials: "uuid",
            }),
            material_uuid: Object.freeze({
                materials: "uuid"
            }),
            basket_item_uuid: Object.freeze({
                basket_items: "uuid"
            }),
            quotation_item_uuid: Object.freeze({
                quotation_items: "uuid"
            }),
            unit_of_measure: Object.freeze({
                unit_of_measures: "name",
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    purchase_order_payments: Object.freeze({
        NAME: "purchase_order_payments",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
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
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            purchase_order_uuid: Object.freeze({
                purchase_orders: "uuid"
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    basket_headers: Object.freeze({
        NAME: "basket_headers",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            date: DATA_TYPES.TIME_STAMP,
            description: DATA_TYPES.DESCRIPTION,
            expected_delivery_date: DATA_TYPES.TIME_STAMP,
            total_price: DATA_TYPES.AMOUNT,
            currency: DATA_TYPES.CURRENCY,
            number_of_items: DATA_TYPES.INTEGER,
            project_uuid: DATA_TYPES.UUID,
            delivery_address: DATA_TYPES.ADDRESS,
            phone_number: DATA_TYPES.PHONE_NUMBER,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            project_uuid: Object.freeze({
                projects: "uuid"
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    basket_items: Object.freeze({
        NAME: "basket_items",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
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
            manufacturer_uuid: Object.freeze([
                "manufacturer_name"
            ]),
            material_uuid: Object.freeze([
                "material_name"
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            basket_uuid: Object.freeze({
                basket_headers: "uuid"
            }),
            manufacturer_material_uuid: Object.freeze({
                manufacturer_materials: "uuid",
            }),
            material_uuid: Object.freeze({
                materials: "uuid"
            }),
            manufacturer_uuid: Object.freeze({
                manufacturers: "uuid"
            }),
            unit_of_measure: Object.freeze({
                unit_of_measures: "name",
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    quotations: Object.freeze({
        NAME: "quotations",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
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
            project_uuid: DATA_TYPES.UUID,
            description: DATA_TYPES.DESCRIPTION,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            vendor_uuid: Object.freeze([
                "vendor_name"
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            basket_uuid: Object.freeze({
                basket_headers: "uuid"
            }),
            vendor_uuid: Object.freeze({
                vendors: "uuid"
            }),
            project_uuid: Object.freeze({
                projects: "uuid"
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    quotation_items: Object.freeze({
        NAME: "quotation_items",
        TYPE: TABLE_TYPES.TRANSACTION_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            id: DATA_TYPES.ID,
            quotation_uuid: DATA_TYPES.UUID,
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
            unit_of_measure: DATA_TYPES.STRING,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({
            material_uuid: Object.freeze([
                "material_name"
            ]),
        }),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({
            quotation_uuid: Object.freeze({
                quotations: "uuid"
            }),
            basket_uuid: Object.freeze({
                basket_headers: "uuid"
            }),
            basket_item_uuid: Object.freeze({
                basket_items: "uuid"
            }),
            vendor_price_list_uuid: Object.freeze({
                vendor_price_lists: "uuid"
            }),
            manufacturer_material_uuid: Object.freeze({
                manufacturer_materials: "uuid",
            }),
            material_uuid: Object.freeze({
                materials: "uuid"
            }),
            unit_of_measure: Object.freeze({
                unit_of_measures: "name",
            }),
            currency: Object.freeze({
                currencies: "name",
            }),
        }),
    }),
    projects: Object.freeze({
        NAME: "projects",
        TYPE: TABLE_TYPES.MASTER_DATA,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            name: DATA_TYPES.NAME,
            description: DATA_TYPES.DESCRIPTION,
            address: DATA_TYPES.STRING,
            phone_number: DATA_TYPES.STRING,
            geo_location: DATA_TYPES.STRING,
            start_date: DATA_TYPES.TIME_STAMP,
            end_date: DATA_TYPES.TIME_STAMP,
            completed: DATA_TYPES.BOOLEAN,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    change_log: Object.freeze({
        NAME: "change_log",
        TYPE: TABLE_TYPES.LOG,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            table_index: DATA_TYPES.TABLE_IDENTIFIER_INDEX,
            table_key: DATA_TYPES.STRING,
            change_mode: DATA_TYPES.CHANGE_MODE,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
    condensed_change_log: Object.freeze({
        NAME: "condensed_change_log",
        TYPE: TABLE_TYPES.LOG,
        KEY_COLUMN: "uuid",
        COLUMNS: Object.freeze({
            uuid: DATA_TYPES.UUID,
            table_index: DATA_TYPES.TABLE_IDENTIFIER_INDEX,
            table_key: DATA_TYPES.STRING,
            change_mode: DATA_TYPES.CHANGE_MODE,
            updated_at: DATA_TYPES.TIME_STAMP,
        }),
        LOOKUP_COLUMNS: Object.freeze({}),
        FOREIGN_KEY_RELATIONSHIPS: Object.freeze({}),
    }),
});

const TABLE_META_INFO = (function () {
    let result = {};
    const tableNames = [];
    for (const [tableName, def] of Object.entries(TABLE_DEFINITIONS)) {
        tableNames.push(tableName);
        const columnNames = Object.keys(def.COLUMNS);

        // Generate flat list of lookup column names from the new structure
        const lookupColumns = [];
        for (const [sourceCol, targetCols] of Object.entries(def.LOOKUP_COLUMNS)) {
            lookupColumns.push(...targetCols);
        }

        let colIndices = {};
        let columns = {};
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
