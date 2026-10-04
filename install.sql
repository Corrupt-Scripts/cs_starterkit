-- Optional: the resource creates this table automatically on start.
CREATE TABLE IF NOT EXISTS `cs_starterkit_claims` (
    `identifier` VARCHAR(100) NOT NULL,
    `license`    VARCHAR(100) DEFAULT NULL,
    `citizenid`  VARCHAR(50)  DEFAULT NULL,
    `name`       VARCHAR(100) DEFAULT NULL,
    `gender`     VARCHAR(10)  DEFAULT NULL,
    `plate`      VARCHAR(8)   DEFAULT NULL,
    `claimed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`),
    KEY `license` (`license`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------------
-- OPTIONAL: mark everyone who already exists as claimed
-- (same as running `starterkitimport` in the server console)
-- Run AFTER the table above exists. Pick the block matching Config.ClaimMode.
-- ------------------------------------------------------------------

-- Config.ClaimMode = 'license'  (default - once per player)
INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name)
SELECT p.license, p.license, MIN(p.citizenid), 'Imported'
FROM players p
WHERE p.license IS NOT NULL
GROUP BY p.license;

-- Config.ClaimMode = 'citizenid'  (once per character) - uncomment to use instead
-- INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name)
-- SELECT CONCAT('cid:', p.citizenid), p.license, p.citizenid, 'Imported'
-- FROM players p
-- WHERE p.citizenid IS NOT NULL;
