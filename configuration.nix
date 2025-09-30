# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, vars, configurationPorts,... }:

{
  system.activationScripts.mountSharedDirectory = { 
    text =''
      printf "mounting shared directory\n"
      mkdir -p /persistent${vars.vm.sharedFolder}
      mount -t 9p -o trans=virtio,version=9p2000.L hostshared /persistent${vars.vm.sharedFolder}
    '';
    deps = ["specialfs"]; 
  };
  system.activationScripts.setupSecretsForUsers.deps = ["mountSharedDirectory"];

  system.activationScripts.setupRightOwnershipPublickeys = {
    text = ''
      for file in /etc/ssh/authorized_keys.d/*; do
        user=$(basename "$file" .pub)
        if id "$user" > /dev/null 2>&1; then
          chown "$user:users" "$file"
        fi
      done
    '';
  };

  environment.persistence."/persistent" = {
    enable = true;  # NB: Defaults to true, not needed
    hideMounts = true;
    directories = [
      "${vars.vm.sharedFolder}"
      # { directory = "/mnt/share/alice"; user = "alice"; mode = "u=rwx,g=rx,o="; }
    ];
  };

  # Can these configs files be modified in subsequents runs? should be moved them into persistent storage?
  environment.etc = {
    cardano-configs-testnet-preview = {
      source = pkgs.cardano-configs-testnet-preview;
    };
    cardano-configs-testnet-preprod = {
      source = pkgs.cardano-configs-testnet-preprod;
    };
    cardano-configs-mainnet = {
      source = pkgs.cardano-configs-mainnet;
    };
  };

  # If you perform changes to the dashboard while the VM is running,
  # you can copy the dashboard JSON and paste it into proper file in the repository.
  # (!) If you don't do that, you would lose the changes if nixos.qcow2 file is removed.
  environment.etc."grafana-dashboards" = {
    source = pkgs.grafana-dashboards;
  };

  # fail2ban custom filter for sshd invalid public keys
  environment.etc = {
    "fail2ban/filter.d/sshd-nixos.local".text = pkgs.lib.mkDefault (pkgs.lib.mkAfter ''
      [Definition]
      failregex = ^.*sshd-session\[\d+\]: Failed publickey for .* from <HOST> port \d+ ssh2.*$
      ignoreregex =
    '');
  };

  # This tutorial focuses on testing NixOS configurations on a virtual machine. 
  # Therefore you will remove the reference to:
  # imports =
  #   [ # Include the results of the hardware scan.
  #     ./hardware-configuration.nix
  #   ];

  # services.openssh.enable = true;
  sops.defaultSopsFile = ./secrets/keys.enc.yaml;
  # This is using an age key that is expected to already be in the filesystem
  # Note: If you are using Impermanence,
  # the key used for secret decryption (sops.age.keyFile, or the host SSH keys)
  # must be in a persisted directory, loaded early enough during boot.
  sops.age.keyFile = "/persistent${vars.vm.sharedFolder}/age-password.key";
  # sops.age.keyFile = "/persistent/mk-password.key";
  # If true, this will generate a new key if the key specified above does not exist
  sops.age.generateKey = false;
  # This is the actual specification of the secrets.
  sops.secrets.alice-password = {};

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  sops.secrets.alice-password.neededForUsers = true;
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    # password = "123";
    hashedPasswordFile = config.sops.secrets.alice-password.path;
    packages = with pkgs; [
      tree
      cardano-node
      cardano-cli
      cardano-auditor
    ];
  };

  # programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List of systemd services available
  systemd.services.cardano-node = let
    cardanoStartupScript = pkgs.writeShellApplication {
      name = "start-cardano";
      text = ''
      # Ensure directories exist
      mkdir -p /persistent${vars.vm.sharedFolder}/cardano-db
      
      # Wait for network interface to be available
      INTERFACE="eth1"
      RETRY_COUNT=0
      MAX_RETRIES=30
      
      while ! ip link show $INTERFACE &>/dev/null && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "Waiting for interface $INTERFACE to be available... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 1
        RETRY_COUNT=$((RETRY_COUNT+1))
      done
      
      if ! ip link show $INTERFACE &>/dev/null; then
        echo "Interface $INTERFACE not found after waiting. Exiting."
        exit 1
      fi
      
      # Get the IP address
      IP=$(${pkgs.iproute2}/bin/ip -o -4 addr show dev "$INTERFACE" | grep -oP "(?<=inet\s)\d+(\.\d+){3}")
      
      if [ -z "$IP" ]; then
        echo "No IP address found for interface $INTERFACE. Exiting."
        exit 1
      fi
      
      echo "Starting cardano-node with IP: $IP"
      exec ${pkgs.cardano-node}/bin/cardano-node run \
        --topology /etc/cardano-configs-mainnet/topology.json \
        --database-path /persistent${vars.vm.sharedFolder}/cardano-db \
        --socket-path /persistent${vars.vm.sharedFolder}/cardano-db/node.socket \
        --host-addr "$IP" \
        --port 3001 \
        --config /etc/cardano-configs-mainnet/config.json
    '';
  };
  in {
    description = "Cardano node startup";
    wantedBy = ["multi-user.target"];
    # Ensure proper dependency order
    after = [ "network-online.target" "sops-nix.target" ];
    wants = [ "network-online.target" ];
    # Add a restart policy
    serviceConfig = {
      Type = "simple";
      User = "alice";
      Group = "users";
      ExecStart = "${cardanoStartupScript}/bin/start-cardano";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    path = [ pkgs.cardano-node pkgs.iproute2 ];
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      PermitEmptyPasswords = "no";
      KbdInteractiveAuthentication = false;
      ChallengeResponseAuthentication = "no";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u";
    };
  };

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "24h";
    bantime-increment = {
      enable = true; # Enable increment of bantime after each violation
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # Do not ban for more than 1 week
      overalljails = true; # Calculate the bantime based on all the violations
    };
    ignoreIP = [
      # Whitelist subnets
      "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16"
      "8.8.8.8" # google dns
      "nixos.wiki" # resolve the IP via DNS
    ];
    jails = {
      sshd.settings = {
        enabled = true;
        backend = "systemd";
      };
      sshd-nixos.settings = {
        enabled = true;
        filter = "sshd-nixos";
        backend = "systemd";
        action = ''%(action_)s[blocktype=DROP]'';
      };
    };
  };

  # TODO: Analize if at some point we need chrony with NTS turning on for more secure time synchronization.
  # Enable chrony for accurate time synchronization (critical for Cardano stake pools)
  # Cheatsheet:
  # Check chrony status
  # $ chronyc tracking
  # View time sources
  # $ chronyc sources -v
  # Check system time sync
  # $ timedatectl status
  services.timesyncd.enable = false; # Disable systemd-timesyncd if using chrony
  services.chrony = {
    enable = true;
    servers = [
      "0.pool.ntp.org"
      "1.pool.ntp.org" 
      "2.pool.ntp.org"
      "3.pool.ntp.org"
      "time.cloudflare.com" 
      "time.google.com"
    ];
    extraConfig = ''
      # Allow large time corrections on startup;
      # For the first 3 clock updates, make an immediate jump (step) if time is off by more than 1.0 second
      # After that, always use gradual slewing regardless of how far off the clock is
      makestep 1.0 3
      # Notify log time adjustments more than 0.5 seconds
      logchange 0.5
    '';
  };

  # Ref. https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters
  # Access via: http://$VM_IP:9100/metrics
  # and for cardano-node: http://$VM_IP:12798/metrics
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [
      "logind"
      "systemd"
    ];
    disabledCollectors = [
      "textfile"
    ];
    openFirewall = true;
    # TODO: Review which flags we could add!
    # extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" "--collector.wifi" ];
  };

  # Prometheus Server (TODO: Move it to a dedicate server)
  # Access via: http://$VM_IP:9090
  services.prometheus = {
      enable = true;
      port = 9090;
      globalConfig.scrape_interval = "15s"; # Set the scrape interval to every 15 seconds. Default is every 1 minute ("1m").
      globalConfig.evaluation_interval = "15s"; # Evaluate rules every 15 seconds. The default is every 1 minute ("1m").
      scrapeConfigs = [
        {
          # To scrape data from a node exporter to monitor your Linux host metrics.
          job_name = "node-exporter";
          static_configs = [{
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }];
        }
        {
          # To scrape data from the Cardano node
          job_name = "cardano-node";
          static_configs = [{
            targets = [ "localhost:12798" ];
          }];
        }
      ];
   };

  services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0"; # Listen on all interfaces
          http_port = 4001;
          enforce_domain = false;
        };
        # Security settings
        security = {
          # For production, use a proper password or preferably OAuth/LDAP
          admin_user = "admin";
          # Default password is "admin" - user will be prompted to change on first login
        };
      };

      # Optional: Declaratively provision datasources and dashboards
      # This is a powerful feature for managing your Grafana setup as code.
      # See the "Declarative Provisioning" section below for more details.
      provision = {
        enable = true;
        datasources.settings.datasources = [
          # Example Prometheus datasource:
          {
            name = "Prometheus Server";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString config.services.prometheus.port}";
            isDefault = true;
          }
        ];
        dashboards.settings.providers = [
          {
            name = "my-provisioned-dashboards"; # A unique name for your provider
            type = "file"; # The type of provider (usually "file" for local files)
            allowUiUpdates = true; # Set to false if you want to prevent users from modifying these dashboards in the UI
            options = {
              path = "/etc/grafana-dashboards"; # Path to the directory containing your dashboard JSON files
              # Or, if you have a single dashboard file:
              # path = ./grafana-dashboards/my-dashboard.json;
              foldersFromFilesStructure = true; # (Optional) If your dashboards are in subdirectories, they will be organized into folders in Grafana
            };
          }
        ];
      };
  };

  # Open ports in the firewall Or disable the firewall altogether.
  networking.firewall = {
    enable = true;
    # This prevents ip spoofing attacks
    checkReversePath = "loose";
    # Open ports in the firewall.
    allowedTCPPorts = configurationPorts;
    allowedUDPPorts = [];
    # Add your custom iptables rule here
    # extraCommands = "";
    # If you have specific output rules you also need to allow, you can add them to extraCommandsOutput:
    # extraCommandsOutput = "";
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}

