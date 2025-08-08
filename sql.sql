CREATE TABLE IF NOT EXISTS `pen_restaurant_clockin` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `player_id` VARCHAR(50) NOT NULL,
    `restaurant` VARCHAR(100) NOT NULL,
    `clock_in_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `clock_out_time` TIMESTAMP NULL DEFAULT NULL,
    `hours_worked` DECIMAL(5,2) DEFAULT 0.00,
    `status` ENUM('clocked_in', 'clocked_out') DEFAULT 'clocked_in',
    PRIMARY KEY (`id`),
    INDEX `player_restaurant` (`player_id`, `restaurant`),
    INDEX `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pen_restaurant_transactions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `restaurant` VARCHAR(100) NOT NULL,
    `cashier_id` VARCHAR(50) NOT NULL,
    `customer_id` VARCHAR(50) NOT NULL,
    `items` JSON NOT NULL,
    `subtotal` DECIMAL(10,2) NOT NULL,
    `tax` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `total` DECIMAL(10,2) NOT NULL,
    `tip` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `payment_method` VARCHAR(20) DEFAULT 'cash',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `restaurant_date` (`restaurant`, `created_at`),
    INDEX `cashier_idx` (`cashier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pen_restaurant_stats` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `restaurant` VARCHAR(100) NOT NULL,
    `date` DATE NOT NULL,
    `total_revenue` DECIMAL(12,2) DEFAULT 0.00,
    `total_transactions` INT(11) DEFAULT 0,
    `total_tips` DECIMAL(10,2) DEFAULT 0.00,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `restaurant_date` (`restaurant`, `date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pen_restaurant_recipes` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `restaurant` VARCHAR(100) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `type` ENUM('drinks', 'food') NOT NULL,
    `ingredients` JSON NOT NULL,
    `cook_time` INT(11) DEFAULT 10000,
    `description` TEXT,
    `created_by` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `restaurant_type` (`restaurant`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;