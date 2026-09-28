{ ... }:

{
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  virtualisation.docker.enable = true;
  users.users.pulsar = {
    extraGroups = [ "docker" ];
  };
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

  environment.shellAliases = {
    l = "eza -lah";
    ls = "eza";
    tree = "eza --tree --git-ignore";

    h = "history";
    mk = "(){ mkdir -p $1 }";

    cdp = "pwd | wl-copy";

    cp = "cp -i";
    mv = "mv -i";
    cat = "bat";

    rm = "trash";

    realremove = "rm";

    nfu = "sudo nix flake update";
    nrs = "sudo nixos-rebuild switch";
    ngc = "nix-store --gc";
    ns = "nix-shell";

    e = "nvim";
    nivm = "nvim"; # lol.
    cr = "claude --resume";

    g = "git";
    gs = "git status";
    ga = "git add";
    gc = "git commit -m";
    gpu = "git push";
    gpd = "git pull";
    
    sl = "eza";

    neofetch = "fastfetch";
  };
}
