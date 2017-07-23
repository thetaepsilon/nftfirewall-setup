#!/bin/sh

die() {
	echo "[fatal] $1" >&2;
	exit 2;
}

warn() {
	echo "[warn] $1" >&2;
}

conffail() {
	die "Could not set configuration: $1";
}
# note that $path is bound late and set by the code using the below functions.
dirfail() {
	die "Could not create directory: $1 ($path)";
}
trysymlink() {
	ln -s "$1" "$2" || die "Could not create link: $3 ($1 -> $2)";
}
trycd() {
	cd "$1" || die "Could not cd to directory: $2 ($1)";
}
systemctlfail() {
	die "systemctl invocation failed ($1)";
}

usage() {
	echo "Usage: $0 dist_directory runtimeowner runtimegroup" >&2;
	exit 1;
}



if test $# -lt 3; then usage; fi;
distdir="$1";
runtimeowner="$2";
runtimegroup="$2";
if test ! -d  "$distdir"; then die "$distdir does not appear to be a directory"; fi;

e="/etc/nftfirewall";
p="$e/paths";
g="$e/globalcfg"
echo "Please ensure this script is run inside the clone of the nftfirewall-setup repository." >&2;
cp -r 'defaults/nftfirewall' '/etc' || die "Could not install default configuration.";
echo "$distdir" > "$p/dist" || conffail "distribution directory path";
echo "$runtimeowner" > "$g/runtimeowner" || conffail "runtime configuration owner";
echo "$runtimegroup" > "$g/runtimegroup" || conffail "runtime configuration group";

# symlink the two needed scripts into /usr/local/bin.
# nft-firewall-init in particular has to be referenced by absolute path in the systemd unit.
trycd "/usr/local/bin" "local binaries directory";
trysymlink "$distdir/scripts/nftfirewall" '.' 'nftfirewall binary';
trysymlink "$distdir/scripts/nft-firewall-init" '.' 'nftfirewall boot-time init binary';

# note: what follows is init system specific.
# discussions are welcomed on how to move init system "native" code into individual scripts.
# it also currently assumes systemd-networkd as the network manager.
# so we may end up with one script for each (desired/used) combination of service and network manager.

# set up symlinks to dist unit files directory
path="/etc/systemd/symlinks";
desc="systemd unit symlinks directory";
mkdir "$path" || dirfail "$desc";
trycd "$path" "$desc";
# create common symlink to dist directory systemd units
trysymlink "$distdir/systemd" "nftfirewall" "common symlink for systemd unit files";

# main units
trycd "/etc/systemd/system" "systemd system units";
trysymlink "../symlinks/nftfirewall/system/nft-firewall-setup.service" "." "nftfirewall setup service";
trysymlink "../symlinks/nftfirewall/system/firewall-ready.target" "." "firewall target unit";

# only start network manager after firewall target reached
service="systemd-networkd.service";	# this could be changed to other network manager services/units under systemd
path="$service.d";
desc="$service drop-in configuration directory";
# note no trymkdir() because here we don't treat it as fatal if the directory exists already.
mkdir -p "$path" || dirfail "$desc";
trycd "$path" "$desc";
trysymlink '../../symlinks/nftfirewall/drop-ins/wait-for-firewall.conf' '.' "$service firewall dependency";

# enable firewall target.
# we don't enable the firewall init service just yet, as the firewall still remains partially configured.
# the default fail-shut behaviour for security isn't very practical,
# so the user will want to edit configuration first.
systemctl daemon-reload || systemctlfail "reloading changed units";	# update for units added
systemctl enable firewall-ready.target || systemctlfail "enabling firewall target";

# and we're done. prod the user to complete system-specific configuration before enabling firewall.
echo "Install complete, but firewall is not enabled.";
echo "Please create profiles for your interfaces (stable interface naming schemes are strongly recommended).";
echo "When done, the firewall can be enabled for boot start via \"systemctl enable nft-firewall-setup\".";
echo "Firewall has not been boot-initialised, so configuration can be tested by running nft-firewall-init as superuser.";
echo "Please note that if the initial configuration is invalid, the initial firewall will fail-shut to \"deny all\".";
echo "Therefore it is advised to prepare for temporary loss of network connectivity before proceeding.";
