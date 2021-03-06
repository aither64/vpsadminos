{ lib, config, pkgs, ... }:
with lib;

let
  sshd_config = pkgs.writeText "sshd_config" ''
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key
    UsePAM yes
    Port 22
    PidFile /run/sshd.pid
    Protocol 2
    PermitRootLogin yes
    PasswordAuthentication yes
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
  '';
  compat = pkgs.runCommand "runit-compat" {} ''
    mkdir -p $out/bin/
    cat << EOF > $out/bin/poweroff
#!/bin/sh
exec runit-init 0
EOF
    cat << EOF > $out/bin/reboot
#!/bin/sh
exec runit-init 6
EOF
    chmod +x $out/bin/{poweroff,reboot}
  '';
  gettyCmd = extraArgs: "${pkgs.utillinux}/bin/setsid ${pkgs.utillinux}/sbin/agetty --autologin root --login-program ${pkgs.shadow}/bin/login ${extraArgs}";

  apparmor_paths = concatMapStrings (s: " -I ${s}/etc/apparmor.d")
          ([ pkgs.apparmor-profiles ] ++ config.security.apparmor.packages);
  profile = "${pkgs.lxc}/etc/apparmor.d/lxc-containers";
in
{
  environment.systemPackages = [ compat pkgs.socat ];
  environment.etc = with config.networking; (lib.mkMerge [{
    "runit/1".source = pkgs.writeScript "1" ''
      #!${pkgs.stdenv.shell}

      ip addr add 127.0.0.1/8 dev lo
      ip link set lo up

      ip a

      ${lib.optionalString static.enable ''
      ip addr add ${static.ip} dev ${static.interface}
      ip link set ${static.interface} up
      ip route add ${static.route} dev ${static.interface}
      ip route add default via ${static.gw} dev ${static.interface}

      ip a
      ip r
      ''}

      ${lib.optionalString config.networking.dhcp ''
      ${pkgs.dhcpcd.override { udev = null; }}/sbin/dhcpcd
      ''}
      #mkdir /bin/
      ln -s /etc/service /service
      #ln -s ${pkgs.stdenv.shell} /bin/sh

      ${lib.optionalString config.networking.ntpdate ''
      #${pkgs.ntp}/bin/ntpdate 192.168.2.1
      ''}

      ${lib.optionalString config.networking.lxcbr ''
      brctl addbr lxcbr0
      brctl setfd lxcbr0 0
      ip addr add 192.168.1.1 dev lxcbr0
      ip link set promisc on lxcbr0
      ip link set lxcbr0 up
      ip route add 192.168.1.0/24 dev lxcbr0
      echo 1 > /proc/sys/net/ipv4/ip_forward
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      ''}

      # disable DPMS on tty's
      echo -ne "\033[9;0]" > /dev/tty0

      for x in ${lib.concatStringsSep " " config.boot.kernelModules}; do
        modprobe $x
      done

      # LXC
      mkdir -p /var/lib/lxc/rootfs

      # Suids
      chmod 04755 $( which newuidmap )
      chmod 04755 $( which newgidmap )
      chmod 04755 ${pkgs.lxc}/libexec/lxc/*

      # CGroups
      mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
      mkdir /sys/fs/cgroup/unified
      mount -t cgroup2 none /sys/fs/cgroup/unified
      cgconfigparser -l /etc/cgconfig.conf

      # AppArmor
      mount -t securityfs securityfs /sys/kernel/security
      ${pkgs.apparmor-parser}/bin/apparmor_parser -rKv ${apparmor_paths} "${profile}"

      # Permission fixes
      chmod 777 /tmp

      touch /etc/runit/stopit
      chmod 0 /etc/runit/stopit
    '';

    "runit/2".source = pkgs.writeScript "2" ''
      #!/bin/sh
      exec runsvdir -P /etc/service
    '';

    "runit/3".source = pkgs.writeScript "3" ''
      #!/bin/sh
      echo and down we go
    '';

    "service/sshd/run".source = pkgs.writeScript "sshd_run" ''
      #!/bin/sh
      ${pkgs.openssh}/bin/sshd -f ${sshd_config}
    '';

    "service/getty-0/run".source = pkgs.writeScript "getty-0" ''
      #!/bin/sh
      ${gettyCmd "--noclear --keep-baud ttyS0 115200,38400,9600 vt100"}
    '';

    "service/getty-1/run".source = pkgs.writeScript "getty-1" ''
      #!/bin/sh
      ${gettyCmd "--noclear --keep-baud ttyS1 115200,38400,9600 vt100"}
    '';

    "service/lxcfs/run".source = pkgs.writeScript "lxcfs" ''
      #!/bin/sh
      mkdir -p /var/lib/lxcfs
      ${pkgs.lxcfs}/bin/lxcfs /var/lib/lxcfs
    '';
  }

  (mkIf (config.vpsadminos.nix) {
     "service/nix/run".source = pkgs.writeScript "nix" ''
      #!/bin/sh
      nix-store --load-db < /nix/store/nix-path-registration
      nix-daemon
    '';
  })

  (mkIf (config.networking.dhcpd) {
    "service/dhcpd/run".source = pkgs.writeScript "dhcpd" ''
      #!/bin/sh
      mkdir -p /var/lib/dhcp
      touch /var/lib/dhcp/dhcpd4.leases
      ${pkgs.dhcp}/sbin/dhcpd -4 -f \
        -pf /run/dhcpd4.pid \
        -cf /etc/dhcpd/dhcpd4.conf \
        -lf /var/lib/dhcp/dhcpd4.leases \
        lxcbr0
    '';
  })
  ]);
}
