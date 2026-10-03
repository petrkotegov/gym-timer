#!/usr/bin/env bash
# Поднимаем один статический сайт на свободных портах 80/443 тестового сервера.
set -euo pipefail

address=${1:?Укажите адрес сайта}
[[ "$address" =~ ^(http://)?[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Некорректный адрес сайта' >&2; exit 1; }
release=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_dir=/opt/apps/gym-timer/test
container=gym-timer-test
image=caddy:2.11.4-alpine

# Подготавливаем образ и проверяем конфигурацию до изменения работающего сайта.
docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image"
mkdir -p "$app_dir/site" "$app_dir/config" "$app_dir/data" "$release/config"
cat > "$release/config/Caddyfile" <<EOF
# Домен включает автоматический HTTPS; http://IP служит временным адресом.
$address {
	root * /srv
	encode zstd gzip
	header Cache-Control "no-cache"
	file_server
}
EOF
docker run --rm --network none \
  --mount "type=bind,src=$release/config,dst=/etc/caddy,readonly" \
  "$image" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# Атомарно обновляем страницу и конфигурацию в постоянных каталогах.
install -m 644 "$release/index.html" "$app_dir/site/index.html.new"
mv "$app_dir/site/index.html.new" "$app_dir/site/index.html"
install -m 644 "$release/config/Caddyfile" "$app_dir/config/Caddyfile.new"
mv "$app_dir/config/Caddyfile.new" "$app_dir/config/Caddyfile"

# Повторный деплой перечитывает настройки без остановки сервера и потери сертификатов.
if docker container inspect "$container" >/dev/null 2>&1; then
  docker start "$container" >/dev/null
  docker exec "$container" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
else
  docker run -d --name "$container" --restart unless-stopped \
    -p 80:80 -p 443:443 -p 443:443/udp \
    --mount "type=bind,src=$app_dir/site,dst=/srv,readonly" \
    --mount "type=bind,src=$app_dir/config,dst=/etc/caddy,readonly" \
    --mount "type=bind,src=$app_dir/data,dst=/data" \
    "$image"
fi

echo "Gym Timer опубликован: $address (для HTTPS дождитесь DNS и выпуска сертификата)"
