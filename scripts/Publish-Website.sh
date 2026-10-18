#!/usr/bin/env bash
set -Eeuo pipefail

domain='linyiweics.cn'
site_root='/www/wwwroot/linyiweics.cn'
stage="${1:?A staging directory is required}"
backup=''

on_error() {
    local code=$?
    printf '\nDeployment failed (exit %s).\n' "$code" >&2
    if [[ -n "$backup" && -d "$backup" ]]; then
        printf 'Backup: %s\n' "$backup" >&2
        printf 'To restore the previous site files, run:\ncp -a -- "%s/." "%s/"\n' "$backup" "$site_root" >&2
    fi
    exit "$code"
}
trap on_error ERR

[[ "$stage" =~ ^/root/linyiweics-site-upload-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$ ]]
[[ "$(id -u)" == '0' ]]
[[ -d "$site_root" ]]
[[ "$(readlink -f -- "$site_root")" == "$site_root" ]]
cd -- "$stage"

site_files=(index.html 404.html styles.css script.js forest-mist.png '林毅玮.jpg')
for file in "${site_files[@]}"; do
    [[ -f "$file" && ! -L "$file" ]]
done
sha256sum --check sha256sum.txt
printf '\nNginx executable used for the configuration check: '
command -v nginx
nginx -t

deployment_id="${stage#/root/linyiweics-site-upload-}"
backup_candidate="/root/linyiweics.cn-backup-$deployment_id"
[[ ! -e "$backup_candidate" ]]
cp -a -- "$site_root" "$backup_candidate"
backup="$backup_candidate"
printf '\nBackup completed: %s\n' "$backup"
printf 'Rollback command: cp -a -- "%s/." "%s/"\n\n' "$backup" "$site_root"
printf '%s\n' "$backup" > backup-path.txt

# Copy only public assets. Keep panel files, TLS settings and other site files.
for file in "${site_files[@]}"; do
    cp -- "$file" "$site_root/$file"
    chmod 644 -- "$site_root/$file"
done
(
    cd -- "$site_root"
    sha256sum --check "$stage/sha256sum.txt"
)

http_status=$(curl --noproxy '*' --silent --show-error --max-time 20 \
    --output "$stage/http-body.html" --write-out '%{http_code}' \
    --header "Host: $domain" http://127.0.0.1/)
case "$http_status" in
    200)
        cmp --silent "$stage/http-body.html" "$site_root/index.html"
        printf '\nHTTP check passed: Nginx served the uploaded homepage.\n'
        ;;
    301|302|307|308)
        printf '\nHTTP returned redirect %s; checking the public HTTPS endpoint next.\n' "$http_status"
        ;;
    *)
        printf '\nUnexpected local HTTP status: %s\n' "$http_status" >&2
        false
        ;;
esac

# TLS is verified normally. Never bypass an invalid certificate with -k.
if https_status=$(curl --noproxy '*' --silent --show-error --max-time 25 \
    --output "$stage/https-body.html" --write-out '%{http_code}' "https://$domain/"); then
    if [[ "$https_status" == '200' ]] && cmp --silent "$stage/https-body.html" "$site_root/index.html"; then
        printf '\nHTTPS check passed: valid TLS and the uploaded homepage.\n'
        printf 'Website: https://%s/\n' "$domain"
    elif [[ "$https_status" != '200' ]]; then
        printf '\nHTTPS NEEDS ATTENTION: expected HTTP 200, received %s.\n' "$https_status" >&2
        printf 'Check the HTTPS virtual host and any redirect or upstream response. Uploaded files and backup are retained.\n' >&2
        exit 2
    else
        printf '\nHTTPS NEEDS ATTENTION: HTTP 200 and TLS succeeded, but the public homepage differs from the uploaded index.html.\n' >&2
        if grep -qi 'Welcome to nginx' "$stage/https-body.html"; then
            printf 'The HTTPS response is the default Nginx welcome page. Check the active HTTPS server_name, root and index settings.\n' >&2
            printf 'If multiple Nginx installations exist, identify the running master process before changing or reloading configuration.\n' >&2
        else
            printf 'Check HTTPS root/index/location, DNS/upstream routing, and any CDN or server-side content transformation.\n' >&2
        fi
        printf 'Uploaded homepage and public response SHA-256:\n' >&2
        sha256sum -- "$site_root/index.html" "$stage/https-body.html" >&2
        printf 'The fetched response is saved at: %s/https-body.html\n' "$stage" >&2
        printf 'Uploaded files and backup are retained. No automatic rollback was performed.\n' >&2
        exit 2
    fi
else
    printf '\nHTTPS NEEDS ATTENTION: files are published, but TLS/443/DNS could not be verified.\n' >&2
    printf 'Check the domain HTTPS server block, certificate and port 443. Existing Nginx/SSL configuration was not changed.\n' >&2
    exit 2
fi
