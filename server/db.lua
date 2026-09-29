DB = { ready = false }

local TABLES = {
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealerships` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(64) NOT NULL,
            `type` VARCHAR(32) NOT NULL DEFAULT 'cars',
            `mode` VARCHAR(8) NOT NULL DEFAULT 'npc',
            `job` VARCHAR(64) NOT NULL DEFAULT '',
            `settings` LONGTEXT NULL,
            `points` LONGTEXT NULL,
            `created_by` VARCHAR(64) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealership_stock` (
            `dealership_id` INT UNSIGNED NOT NULL,
            `model` VARCHAR(64) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `stock` INT NOT NULL DEFAULT -1,
            PRIMARY KEY (`dealership_id`, `model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealership_orders` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `dealership_id` INT UNSIGNED NOT NULL,
            `model` VARCHAR(64) NOT NULL,
            `quantity` INT NOT NULL DEFAULT 1,
            `cost` INT NOT NULL DEFAULT 0,
            `ordered_by` VARCHAR(64) NOT NULL DEFAULT '',
            `ordered_name` VARCHAR(96) NOT NULL DEFAULT '',
            `arrives_at` INT UNSIGNED NOT NULL,
            `delivered` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `dealership_open` (`dealership_id`, `delivered`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealership_sales` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `dealership_id` INT UNSIGNED NOT NULL,
            `model` VARCHAR(64) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `method` VARCHAR(16) NOT NULL DEFAULT 'bank',
            `plate` VARCHAR(16) NOT NULL DEFAULT '',
            `buyer` VARCHAR(64) NOT NULL DEFAULT '',
            `buyer_name` VARCHAR(96) NOT NULL DEFAULT '',
            `seller` VARCHAR(64) NULL,
            `seller_name` VARCHAR(96) NULL,
            `commission` INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `dealership_id` (`dealership_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealership_finance` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `dealership_id` INT UNSIGNED NOT NULL,
            `citizenid` VARCHAR(64) NOT NULL,
            `plate` VARCHAR(16) NOT NULL,
            `model` VARCHAR(64) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `balance` INT NOT NULL DEFAULT 0,
            `payment` INT NOT NULL DEFAULT 0,
            `payments_left` INT NOT NULL DEFAULT 0,
            `next_due` INT UNSIGNED NOT NULL,
            `missed` INT NOT NULL DEFAULT 0,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `vehicle` LONGTEXT NULL,
            `held_until` INT UNSIGNED NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `status_due` (`status`, `next_due`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_dealership_ledger` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `dealership_id` INT UNSIGNED NOT NULL,
            `amount` INT NOT NULL,
            `kind` VARCHAR(16) NOT NULL DEFAULT 'other',
            `note` VARCHAR(160) NOT NULL DEFAULT '',
            `by_name` VARCHAR(96) NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `dealership_id` (`dealership_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]],
}

function DB.Install()
    for _, statement in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, statement)
        if not ok then
            print(('^1[XS-Dealerships]^0 could not create a table: %s'):format(tostring(err)))
            return false
        end
    end

    DB.ready = true
    return true
end
