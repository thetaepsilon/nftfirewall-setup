# nftfirewall-setup
Setup scripts and initial configuration for nftfirewall

Setup scripts and sane-ish default configuration for [nftfirewall][1].
The setup process assumes the use of systemd for service management;
if this does not match your use case you can happily ignore steps 7 onwards.
The basic idea should be applicable to any sane service management system though:
arrange for any services which configure the network to only be started if and when the firewall has successfully completed.
This is so that networking isn't brought up while the system is still "fail-open",
because if initialisation of the firewall fails the kernel defaults to accept everything.
Patches for other init systems welcome, but please try to honour the above constraint where possibe.

1. Clone this repository and nftfirewall somewhere accessible (e.g. somewhere where it can be symlinked to later)

2. Copy the `defaults/nftfirewall` directory to /etc (directory itself, not the contents).

3. Create the file `/etc/nftfirewall/paths/dist` to contain the path of the nftfirewall directory.
	E.g. if you cloned the repository while inside `/usr/local/packages`,
	so that the repository ended up inside the `nftfirewall` sub-directory,
	the dist path would be `/usr/local/packages/nftfirewall`.

4. (Optional) Create firewall profiles for your local interfaces.
	It is recommended that interfaces are assigned stable names somehow (e.g. systemd does this by default).

5. (Optional) Set the default profile for your local interfaces by editing `/etc/nftfirewall/runtimeconf.default/profiles/$ifname` for each.

6. (Optional) Enable your local interfaces to be managed via nftfirewall by editing `/etc/nftfirewall/runtimeconf.default/interfaces` to include your interfaces on their own lines.

7. (Recommended) Set the owner and group which can access the `/run/nftfirewall/conf` directory
	as desired to allow authorised users to edit the runtime interface profile selection etc.
	This can be set by editing the files `/etc/nftfirewall/globalcfg/runtime-owner`
	and `/etc/nftfirewall/globalcfg/runtime-group`, respectively.

8. Make the unit files under the `systemd/system` directory visible in `/etc/systemd/system`.
	This can be accomplished either by copying them or using symlinks.
	In my setup, I created a symlinks directory in `/etc/systemd`, symlinked the nftfirewall repo in there,
	then used indirect symlinks in `/etc/systemd/system` via this "master" symlink.
	This avoids the need to change many unit file symlinks if the dist directory needs to be moved.

9. symlink the `nftfirewall` and `nft-firewall-init` scripts
	inside the nftfirewall repository's `scripts` directory to `/usr/local/bin`.
	This is so the systemd units (and other network management tools) can see the binaries.

10. (Recommended) use the `wait-for-firewall.conf` systemd drop-in fragment (located within `systemd/drop-ins`)
	to cause network managers to wait for the default firewall configuration.
	This drop-in fragment can be copied or symlinked into `/etc/systemd/system/$network-service.service.d/`,
	and is agnostic of the service it is applied to.

11. `systemctl enable` both `firewall-ready.target` and `nft-firewall-init.service` to have the firewall applied during system boot.
	At this point it is recommended that the firewall's default configuration be checked,
	by calling `sudo nft-firewall-init` or similar.
	Please note that nft is a bit picky about it's input syntax,
	and that an invalid configuration applied during boot will cause a fallback "drop everything" firewall to be applied.



A script to automate this process is Coming Soon™.

[1]: https://github.com/thetaepsilon/nftfirewall
