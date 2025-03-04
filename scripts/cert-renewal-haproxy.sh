#!/usr/bin/env bash

set -euo pipefail

# automation of certificate renewal for let's encrypt and haproxy
# - checks all certificates under /etc/letsencrypt/live and renews
#   those about to expire in less than 4 weeks
# - creates haproxy.pem in /etc/haproxy/certs/ (fixed filename)
# - soft-restarts haproxy to apply new certificates
# usage:
# sudo ./cert-renewal-haproxy.sh

################################################################################
### global settings
################################################################################

LE_CLIENT="certbot"

HAPROXY_RELOAD_CMD="supervisorctl signal HUP haproxy"
HAPROXY_SOFTSTOP_CMD="supervisorctl signal USR1 haproxy"

WEBROOT="/jail"

# Enable to redirect output to logfile (for silent cron jobs)
# Leave it empty to log in STDOUT/ERR (docker log)
LOGFILE="/var/log/certrenewal.log"  # Uncomment to enable logging to file
#LOGFILE=""

################################################################################
### FUNCTIONS
################################################################################

function issueCert {
  $LE_CLIENT certonly --text --webroot --webroot-path "${WEBROOT}" --renew-by-default --agree-tos --email "${EMAIL}" "${1}" &>/dev/null
  return $?
}

function logger_error {
  if [ -n "${LOGFILE}" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [error] ${1}" >> "${LOGFILE}"
  fi
  >&2 echo "[error] ${1}"
}

function logger_info {
  if [ -n "${LOGFILE}" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [info] ${1}" >> "${LOGFILE}"
  else
    echo "[info] ${1}"
  fi
}

################################################################################
### MAIN
################################################################################

le_cert_root="/etc/letsencrypt/live"

# Check if Let's Encrypt directory exists
if [ ! -d "${le_cert_root}" ]; then
  logger_error "${le_cert_root} does not exist!"
  exit 1
fi

# Check certificate expiration and run certificate issue requests
# for those that expire in under 4 weeks
renewed_certs=()
exitcode=0
while IFS= read -r -d '' cert; do
  if ! openssl x509 -noout -checkend $((4*7*86400)) -in "${cert}"; then
    subject="$(openssl x509 -noout -subject -in "${cert}" | grep -o -E 'CN = [^ ,]+' | tr -d 'CN = ')"
    subjectaltnames="$(openssl x509 -noout -text -in "${cert}" | sed -n '/X509v3 Subject Alternative Name/{n;p}' | sed 's/\s//g' | tr -d 'DNS:' | sed 's/,/ /g')"
    domains="-d ${subject}"
    for name in ${subjectaltnames}; do
      if [ "${name}" != "${subject}" ]; then
        domains="${domains} -d ${name}"
      fi
    done
    logger_info "Attempting to renew certificate for ${subject}..."
    issueCert "${domains}"
    if [ $? -ne 0 ]; then
      logger_error "Failed to renew certificate for ${subject}! Check /var/log/letsencrypt/letsencrypt.log."
      exitcode=1
    else
      renewed_certs+=("$subject")
      logger_info "Renewed certificate for ${subject}."
    fi
  else
    logger_info "None of the certificates require renewal."
  fi
done < <(find "${le_cert_root}" -name cert.pem -print0)

# Create haproxy.pem file
mkdir -p /etc/haproxy/certs
for domain in "${renewed_certs[@]}"; do
  OUTPUT_FILE="/etc/haproxy/certs/haproxy.pem"  # Fixed filename
  CERT_DIR="${le_cert_root}/${domain}"
  FULLCHAIN="${CERT_DIR}/fullchain.pem"
  PRIVKEY="${CERT_DIR}/privkey.pem"

  if [ -f "${FULLCHAIN}" ] && [ -f "${PRIVKEY}" ]; then
    # Concatenate fullchain.pem followed by privkey.pem (preferred order for HAProxy)
    if cat "${FULLCHAIN}" "${PRIVKEY}" > "${OUTPUT_FILE}"; then
      logger_info "Created/updated ${OUTPUT_FILE} for ${domain}."
    else
      logger_error "Failed to create ${OUTPUT_FILE} for ${domain}!"
      exit 1
    fi
  else
    logger_error "Certificate files missing for ${domain}! Expected files: ${FULLCHAIN}, ${PRIVKEY}"
    exit 1
  fi
done

# Soft-stop (and implicit restart) of HAProxy if any certificates were renewed
if [ "${#renewed_certs[@]}" -gt 0 ]; then
  logger_info "Reloading HAProxy to apply new certificates..."
  $HAPROXY_SOFTSTOP_CMD
  if [ $? -ne 0 ]; then
    logger_error "Failed to soft-stop HAProxy!"
    exit 1
  else
    logger_info "HAProxy reloaded successfully."
  fi
fi

exit ${exitcode}
