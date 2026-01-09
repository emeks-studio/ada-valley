# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, vars, configurationPorts, ... }: {
  
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

  sops.defaultSopsFile = ./secrets/keys.enc.yaml;
  # This is using an age key that is expected to already be in the filesystem
  # Note: If you are using Impermanence,
  # the key used for secret decryption (sops.age.keyFile, or the host SSH keys)
  # must be in a persisted directory, loaded early enough during boot.
  sops.age.keyFile = "/etc/age-key";
  # If true, this will generate a new key if the key specified above does not exist
  sops.age.generateKey = false;
  # This is the actual specification of the secrets.
  sops.secrets.alice-password-hash = {};

  boot.kernel.sysctl = {
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.ip_forward" = 0;
    "net.ipv4.tcp_synack_retries" = 5;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.tcp_rmem" = "4096 87380 8388608";
    "net.ipv4.tcp_wmem" = "4096 87380 8388608";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  sops.secrets.alice-password-hash.neededForUsers = true;
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPasswordFile = config.sops.secrets.alice-password-hash.path;
    packages = with pkgs; [
      tree
      cardano-node
      cardano-cli
      cardano-auditor
    ];
  };
  
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
          # For targets exposing metrics in the standard Prometheus text format.
          fallback_scrape_protocol = "PrometheusText0.0.4";
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
  #nixosConfigurations.vm.config.system.build.vm
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}