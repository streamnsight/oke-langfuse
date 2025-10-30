resource "random_string" "password_encryption_key" {
    length = 256
    special     = true
    min_lower = 16
    min_upper = 16
    min_special = 16
    min_numeric = 16
}


resource "random_string" "password_encryption_salt" {
    length = 48
    special     = false
    min_lower = 4
    min_upper = 4
    min_numeric = 16
}

resource "random_string" "nextauth_secret" {
    length = 48
    special     = false
    min_lower = 4
    min_upper = 4
    min_numeric = 16
}


resource "random_string" "clickhouse_password" {
    length = 20
    special     = true
    min_lower = 4
    min_upper = 4
    min_special = 2
    min_numeric = 4
}