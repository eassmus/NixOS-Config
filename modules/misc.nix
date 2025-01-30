{ ... }:

{
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  environment.shellAliases = {
    ds = "echo 'Going to DeepSeek DIR' && cd ~/Projects/WN25/LocalDeepSeek/ && nix-shell";
  };
}
