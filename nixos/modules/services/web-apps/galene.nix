{
  config,
  lib,
  options,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.services.galene;
  opt = options.services.galene;
  defaultstateDir = "/var/lib/galene";
  defaultrecordingsDir = "${cfg.stateDir}/recordings";
  defaultgroupsDir = "${cfg.stateDir}/groups";
  defaultdataDir = "${cfg.stateDir}/data";
in
{
  options = {
    services.galene = {
      enable = mkEnableOption "Galene Service";

      stateDir = mkOption {
        default = defaultstateDir;
        type = types.path;
        description = ''
          The directory where Galene stores its internal state. If left as the default
          value this directory will automatically be created before the Galene server
          starts, otherwise the sysadmin is responsible for ensuring the directory
          exists with appropriate ownership and permissions.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "galene";
        description = "User account under which galene runs.";
      };

      group = mkOption {
        type = types.str;
        default = "galene";
        description = "Group under which galene runs.";
      };

      insecure = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether Galene should listen in http or in https. If left as the default
          value (false), Galene needs to be fed a private key and a certificate.
        '';
      };

      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/path/to/your/cert.pem";
        description = ''
          Path to the server's certificate. The file is copied at runtime to
          Galene's data directory where it needs to reside.
        '';
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/path/to/your/key.pem";
        description = ''
          Path to the server's private key. The file is copied at runtime to
          Galene's data directory where it needs to reside.
        '';
      };

      httpAddress = mkOption {
        type = types.str;
        default = "";
        description = "HTTP listen address for galene.";
      };

      httpPort = mkOption {
        type = types.port;
        default = 8443;
        description = "HTTP listen port.";
      };

      turnAddress = mkOption {
        type = types.str;
        default = "auto";
        example = "127.0.0.1:1194";
        description = "Built-in TURN server listen address and port. Set to \"\" to disable.";
      };

      staticDir = mkOption {
        type = types.path;
        default = "${cfg.package.static}/static";
        defaultText = literalExpression ''"''${package.static}/static"'';
        example = "/var/lib/galene/static";
        description = "Web server directory.";
      };

      recordingsDir = mkOption {
        type = types.path;
        default = defaultrecordingsDir;
        defaultText = literalExpression ''"''${config.${opt.stateDir}}/recordings"'';
        example = "/var/lib/galene/recordings";
        description = "Recordings directory.";
      };

      dataDir = mkOption {
        type = types.path;
        default = defaultdataDir;
        defaultText = literalExpression ''"''${config.${opt.stateDir}}/data"'';
        example = "/var/lib/galene/data";
        description = "Data directory.";
      };

      groupsDir = mkOption {
        type = types.path;
        default = defaultgroupsDir;
        defaultText = literalExpression ''"''${config.${opt.stateDir}}/groups"'';
        example = "/var/lib/galene/groups";
        description = "Web server directory.";
      };

      package = mkPackageOption pkgs "galene" { };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.galene = {
      description = "galene";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${optionalString (cfg.insecure != true && cfg.certFile != null && cfg.keyFile != null) ''
          install -m 700 -o '${cfg.user}' -g '${cfg.group}' ${cfg.certFile} ${cfg.dataDir}/cert.pem
          install -m 700 -o '${cfg.user}' -g '${cfg.group}' ${cfg.keyFile} ${cfg.dataDir}/key.pem
        ''}
      '';

      serviceConfig = mkMerge [
        {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.stateDir;
          ExecStart = ''
            ${cfg.package}/bin/galene \
            ${optionalString (cfg.insecure) "-insecure"} \
            -http ${cfg.httpAddress}:${toString cfg.httpPort} \
            -turn ${cfg.turnAddress} \
            -data ${cfg.dataDir} \
            -groups ${cfg.groupsDir} \
            -recordings ${cfg.recordingsDir} \
            -static ${cfg.staticDir}'';
          Restart = "always";
          # Upstream Requirements
          LimitNOFILE = 65536;
          StateDirectory =
            [ ]
            ++ optional (cfg.stateDir == defaultstateDir) "galene"
            ++ optional (cfg.dataDir == defaultdataDir) "galene/data"
            ++ optional (cfg.groupsDir == defaultgroupsDir) "galene/groups"
            ++ optional (cfg.recordingsDir == defaultrecordingsDir) "galene/recordings";

          # Hardening
          CapabilityBoundingSet = [ "" ];
          DeviceAllow = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          ReadWritePaths = cfg.recordingsDir;
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        }
      ];
    };

    users.users = mkIf (cfg.user == "galene") {
      galene = {
        description = "galene Service";
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "galene") {
      galene = { };
    };
  };
  meta.maintainers = with lib.maintainers; [ rgrunbla ];
}
