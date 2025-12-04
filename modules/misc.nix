{ ... }:

{
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  environment.shellAliases = {
    l = "eza -lah";
    ls = "eza";
    tree = "eza --tree --git-ignore";

    c = "clear";
    h = "history";
    mk = "(){ mkdir -p $1 }";

    cdp = "pwd | wl-copy";

    cp = "cp -i";
    mv = "mv -i";
    cat = "bat";

    realrm = "rm";

    rm = "trash";

    nfu = "sudo nix flake update";
    nrs = "sudo nixos-rebuild switch";
    ngc = "nix-store --gc";
    ns = "nix-shell";

    e = "nvim";

    size = "du -bsh $(ls -A) | sort -h";
  };
}
