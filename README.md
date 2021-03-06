# vpsadminOS

vpsadminOS is a small experimental OS for virtualisation purposes.

Provides environment to run unprivileged lxc containers with nesting and apparmor.

Based on [not-os](https://github.com/cleverca22/not-os/) - small experimental OS for embeded situations.

It is also based on NixOS, but compiles down to a custom kernel, initrd, and a squashfs root while
reusing packages and some modules from [nixpkgs](https://github.com/NixOS/nixpkgs/).

## Technologies

- kernel
- apparmor
- lxc, lxcfs
- criu
- runit
- bird

## Building

```bash
git clone https://github.com/vpsfreecz/vpsadminos/
cd vpsadminos

# temporarily this needs vpsadminos branch from sorki/nixpkgs

git clone https://github.com/sorki/nixpkgs --branch vpsadminos
export NIX_PATH=`pwd`

cd vpsadminos
make

# to run under qemu
make qemu
```

## Usage

```bash
# Login via ssh or use qemu terminal with autologin
ssh -p 2222 localhost

# Create a zpool:
dd if=/dev/zero of=/lxc.zpool bs=1M count=4096 && zpool create lxc /lxc.zpool

# Run osctld:
osctld

# Fetch OS templates:
wget https://s.hvfn.cz/~aither/pub/tmp/templates/ubuntu-16.04-x86_64-vpsfree.tar.gz
wget https://s.hvfn.cz/~aither/pub/tmp/templates/debian-9-x86_64-vpsfree.tar.gz
wget https://s.hvfn.cz/~aither/pub/tmp/templates/centos-7.3-x86_64-vpsfree.tar.gz
wget https://s.hvfn.cz/~aither/pub/tmp/templates/alpine-3.6-x86_64-vpsfree.tar.gz

# Create a user:
osctl user new --ugid 5000 --offset 666000 --size 65536 myuser01

# Create a container:
osctl ct new --user myuser01 --template ubuntu-16.04-x86_64-vpsfree.tar.gz myct01

# Configure container routing:
osctl ct set --route-via 10.100.10.100/30 myct01
osctl ct ip add myct01 1.2.3.4

# Start the container:
osctl ct start myct01

# Work with containers:
osctl ct ls
osctl ct attach myct01
osctl ct console myct01
osctl ct exec myct01 ip addr

# Further information:
osctl help user
osctl help ct

# Profit
```

### Nested containers

To allow nesting, you need to edit containers `config` file
and uncomment `nesting.conf` include line following this line:

```
# Uncomment the following line to support nesting containers:
# include = ...
```

## Building specific targets:

```
nix-build -A config.system.build.tftpdir -o tftpdir
nix-build -A config.system.build.squashfs
```

## Docs:

* https://linuxcontainers.org/
* http://containerops.org/2013/11/19/lxc-networking/
* http://blog.benoitblanchon.fr/lxc-unprivileged-container/

## iPXE

There is a support for generating iPXE config files, that will check the cryptographic signature over all images, to ensure only authorized files can run on the given hardware.
This also rebuilds iPXE to contain keys to be used for signature verification.
