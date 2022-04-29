#!/usr/bin/with-contenv bashio
# ==============================================================================
# Prepare the Samba service for running
# ==============================================================================
declare password
declare username
declare -a interfaces
export HOSTNAME

# Check Login data
if ! bashio::config.has_value 'username' || ! bashio::config.has_value 'password'; then
    bashio::exit.nok "Setting a username and password is required!"
fi

# Read hostname from API or setting default "hassio"
HOSTNAME=$(bashio::info.hostname)
if bashio::var.is_empty "${HOSTNAME}"; then
    bashio::log.warning "Can't read hostname, using default."
    HOSTNAME="hassio"
fi
bashio::log.info "Hostname: ${HOSTNAME}"

# Determine interfaces list
if bashio::config.exists 'interfaces'; then
    # Configuration exists, use configured values
    for interface in $(bashio::config 'interfaces'); do
        interfaces+=("${interface}")
    done
else
    # Configuration doesn't exist, default to the official add-on
    # Get supported interfaces
    for interface in $(bashio::network.interfaces); do
        interfaces+=("${interface}")
    done
	# Add default interface if it is not part of the supported interfaces list
	default_interface=$(bashio::network.name)
	if ! printf '%s\n' "${interfaces[@]}" | grep -Fxq -- "${default_interface}"; then
	    interfaces+=("${default_interface}")
	fi
    interfaces+=("lo")
fi
bashio::log.info "Interfaces: $(printf '%s ' "${interfaces[@]}")"

# Generate Samba configuration.
jq ".interfaces = $(jq -c -n '$ARGS.positional' --args -- "${interfaces[@]}")" /data/options.json \
    | tempio \
      -template /usr/share/tempio/smb.gtpl \
      -out /etc/samba/smb.conf

# Init user
username=$(bashio::config 'username')
password=$(bashio::config 'password')
addgroup "${username}"
adduser -D -H -G "${username}" -s /bin/false "${username}"
# shellcheck disable=SC1117
echo -e "${password}\n${password}" \
    | smbpasswd -a -s -c "/etc/samba/smb.conf" "${username}"
