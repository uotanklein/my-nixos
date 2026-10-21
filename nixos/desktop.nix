{ config, lib, pkgs, inputs, migrationUser, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  shell = inputs.caelestia.packages.${system}.with-cli;
  cli = inputs.caelestia.inputs.caelestia-cli.packages.${system}.default;
in {
  # This module intentionally does not define fileSystems, boot.loader,
  # passwords, or system.stateVersion. Keep those from the fresh installation.
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = lib.mkForce "uotanklein";
  networking.networkmanager.enable = lib.mkForce true;
  networking.wireless.enable = lib.mkForce false;
  time.timeZone = lib.mkForce "Europe/Moscow";
  i18n.defaultLocale = lib.mkForce "ru_RU.UTF-8";
  i18n.supportedLocales = [ "ru_RU.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
  console.keyMap = lib.mkForce "ruwin_alt_sh-UTF-8";
  console.font = "cyr-sun16";
  services.xserver.xkb = {
    layout = lib.mkForce "us,ru";
    options = lib.mkForce "grp:win_space_toggle,grp:alt_shift_toggle";
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # Blackwell / RTX 5070 requires NVIDIA's open kernel modules.
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  security.rtkit.enable = true;
  services.pulseaudio.enable = lib.mkForce false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  # A complete login path for nixos-minimal; no full desktop environment required.
  services.displayManager.gdm.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      user = "greeter";
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd "
        + lib.escapeShellArg "${pkgs.uwsm}/bin/uwsm start -F -- ${config.programs.hyprland.package}/bin/Hyprland";
    };
  };
  security.sudo.enable = true;
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.dconf.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  programs.nix-ld.enable = true;
  programs.amnezia-vpn.enable = true;
  programs.firefox.enable = true;

  # Also creates the account when extending an otherwise bare minimal installation.
  # The setup script asks for its password interactively after activation.
  users.users.${migrationUser} = {
    isNormalUser = lib.mkDefault true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };

  environment.systemPackages = with pkgs; [
    shell cli
    kitty kdePackages.dolphin gnome-text-editor gnome-calculator btop
    git curl wget unzip zip jq python3
    uwsm dbus libnotify polkit_gnome tuigreet
    wl-clipboard cliphist fuzzel hyprpicker grim slurp swappy
    brightnessctl ddcutil lm_sensors
    pipewire wireplumber pulseaudio pavucontrol
    bluez blueman
    fish mpv pwvucontrol
    bibata-cursors qt6Packages.qt6ct
  ];
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-color-emoji
    rubik material-symbols nerd-fonts.caskaydia-cove
  ];

  # A polkit agent for GUI actions in the Hyprland/UWSM session.
  systemd.user.services.migration-polkit-agent = {
    description = "Polkit authentication agent for Hyprland";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };
}
