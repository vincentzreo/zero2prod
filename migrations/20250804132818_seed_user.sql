-- Add migration script here
INSERT INTO
    users (user_id, username, password_hash)
VALUES
    (
        'd3b07384-d9a1-4c2f-8fb3-8c1f2d4e5f6a',
        'admin',
        '$argon2id$v=19$m=15000,t=2,p=1$cY5QJalZy2GXffJLfHQEKQ$ky1MLEzPfoC1mzBK1/WJdPgwCtyJ//uF6Rv0Ud0J0Lc'
    )