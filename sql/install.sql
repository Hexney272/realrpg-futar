-- ==========================================
-- RealRPG Futár Munka Rendszer
-- Adatbázis installáció
-- ==========================================

CREATE TABLE IF NOT EXISTS `seerpg_futar_skills` (
    `identifier` VARCHAR(60) NOT NULL,
    `skill_points` INT DEFAULT 0,
    `total_deliveries` INT DEFAULT 0,
    `total_rounds` INT DEFAULT 0,
    `total_earnings` BIGINT DEFAULT 0,
    `best_round_pay` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ha már létezik a tábla, de hiányoznak az új oszlopok:
-- ALTER TABLE `seerpg_futar_skills` ADD COLUMN `total_earnings` BIGINT DEFAULT 0 AFTER `total_rounds`;
-- ALTER TABLE `seerpg_futar_skills` ADD COLUMN `best_round_pay` INT DEFAULT 0 AFTER `total_earnings`;


-- ==========================================
-- Futár Bolt vásárlások tábla
-- ==========================================
CREATE TABLE IF NOT EXISTS `seerpg_futar_purchases` (
    `id` INT AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `upgrade_id` VARCHAR(60) NOT NULL,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_purchase` (`identifier`, `upgrade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
