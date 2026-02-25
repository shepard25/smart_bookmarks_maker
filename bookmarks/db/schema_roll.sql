CREATE
EXTENSION IF NOT EXISTS pgcrypto;
CREATE
EXTENSION IF NOT EXISTS "uuid-ossp";


-- 1. Таблица пользователей
CREATE TABLE IF NOT EXISTS bkmrk_users
(
    id
    SERIAL
    PRIMARY
    KEY,
    created_at
    TIMESTAMPTZ
    DEFAULT
    now
(
),
    notion_token_encrypted TEXT, -- Сюда n8n будет класть зашифрованный ключ
    notion_db_id TEXT, -- ID базы в Notion
    subscription_status TEXT DEFAULT 'trial', -- trial, active, expired
    valid_until TIMESTAMPTZ DEFAULT
(
    now
(
) + interval '3 days') -- 3 дня триала по умолчанию
    );

-- 2. Таблица авторизации (связываем TG ID с системным ID)
CREATE TABLE IF NOT EXISTS bkmrk_user_auth
(
    id
    SERIAL
    PRIMARY
    KEY,
    user_id
    INTEGER
    REFERENCES
    bkmrk_users
(
    id
) ON DELETE CASCADE,
    auth_provider TEXT NOT NULL DEFAULT 'telegram',
    auth_id BIGINT UNIQUE NOT NULL, -- Это tg_user_id
    created_at TIMESTAMPTZ DEFAULT now
(
)
    );

-- 3. Таблица закладок с индексируемыми фасетами
CREATE TABLE IF NOT EXISTS bookmarks
(
    id
    SERIAL
    PRIMARY
    KEY,
    user_id
    INTEGER
    REFERENCES
    bkmrk_users
(
    id
) ON DELETE CASCADE,
    title TEXT,
    url TEXT NOT NULL,
    -- Наши 4 фасета как массивы
    facet_format TEXT[] DEFAULT '{}',
    facet_topic TEXT[] DEFAULT '{}',
    facet_function TEXT[] DEFAULT '{}',
    facet_tech_stack TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now
(
)
    );

-- 4. Индексы для мгновенного поиска по фасетам (GIN индексы)
CREATE INDEX IF NOT EXISTS idx_bookmarks_format ON bookmarks USING GIN (facet_format);
CREATE INDEX IF NOT EXISTS idx_bookmarks_topic ON bookmarks USING GIN (facet_topic);
CREATE INDEX IF NOT EXISTS idx_bookmarks_function ON bookmarks USING GIN (facet_function);
CREATE INDEX IF NOT EXISTS idx_bookmarks_tech ON bookmarks USING GIN (facet_tech_stack);

-- 5. VIEW для n8n (чтобы за один SELECT получать всё о юзере)
CREATE
OR REPLACE VIEW v_user_config AS
SELECT ua.auth_id              as tg_user_id,
       u.id                    as user_id,
       u.notion_db_id,
       u.notion_token_encrypted,
       u.subscription_status,
       (u.valid_until > now()) as has_access -- Простая проверка: оплачено или нет
FROM bkmrk_user_auth ua
         JOIN bkmrk_users u ON ua.user_id = u.id;