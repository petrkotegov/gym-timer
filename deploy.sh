#!/usr/bin/env bash
# Копируем статический сайт на сервер и запускаем его через Caddy.
set -euo pipefail

target=${1:?Укажите SSH-хост, например cr_test}
address=${2:?Укажите домен или HTTP-адрес, например gym.example.com}

# Разрешаем только простые адреса: аргументы дальше передаются через SSH.
[[ "$target" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@-]*$ ]] || { echo 'Некорректный SSH-хост' >&2; exit 1; }
[[ "$address" =~ ^(http://)?[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Некорректный адрес сайта' >&2; exit 1; }

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
release="/opt/apps/gym-timer/test/releases/$(date -u +%Y%m%dT%H%M%S)-$$"
ssh_options=(-o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2)

# Передаём только страницу и скрипт запуска; незаконченная загрузка не меняет сайт.
echo "Загружаем Gym Timer на $target"
ssh "${ssh_options[@]}" "$target" "mkdir -p '$release'"
tar -C "$project_dir" -cf - index.html deploy/run.sh |
  ssh "${ssh_options[@]}" "$target" "tar -xf - -C '$release'"

# Сертификаты и настройки хранятся вне каталога конкретного релиза.
ssh "${ssh_options[@]}" "$target" "bash '$release/deploy/run.sh' '$address'"
