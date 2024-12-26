{ lib, pkgs }:

let
  imgLink = "https://w.wallhaven.cc/full/p8/wallhaven-p8jv99.jpg";

  image = pkgs.fetchurl {
    url = imgLink;
    sha256 = "sha256-LFaqLWkh+GNNHYW/d09oGsTop7BmCIg5k3vxdOFjHlc=";
  };

  themeIni = [
    {
      section = "General";
      key = "screenwidth";
      value = "2560";
    }
    {
      section = "General";
      key = "screenheight";
      value = "1440";
    }
    {
      section = "General";
      key = "Font";
      value = "JetBrains Mono";
    }
    {
      section = "General";
      key = "FontSize";
      value = "22";
    }
    {
      section = "General";
      key = "HeaderText";
      value = "";
    }
    {
      section = "General";
      key = "HourFormat";
      value = "hh:mm AP";
    }
    {
      section = "General";
      key = "DateFormat";
      value = "dddd MM-dd-yy";
    }
    {
      section = "General";
      key = "Background";
      value = "Backgrounds/background.jpg";
    }
    {
      section = "General";
      key = "MainColor";
      value = "#e9a6fd";
    }
    {
      section = "General";
      key = "AccentColor";
      value = "#82aee8";
    }
  ];
in
pkgs.stdenv.mkDerivation {
  name = "sddm-theme-astro";
  src = pkgs.fetchFromGitHub {
    owner = "gpskwlkr";
    repo = "sddm-astronaut-theme";
    rev = "468a100460d5feaa701c2215c737b55789cba0fc";
    sha256 = "1h20b7n6a4pbqnrj22y8v5gc01zxs58lck3bipmgkpyp52ip3vig";
  };
  installPhase = ''
    mkdir -p $out
    cp -R ./* $out/
    cd $out/
    rm $out/Backgrounds/background.png
    cp -r ${image} $out/Backgrounds/background.jpg
    ${lib.concatMapStringsSep "\n" (e: ''
      ${pkgs.crudini}/bin/crudini --set --inplace $out/theme.conf \
        "${e.section}" "${e.key}" "\"${e.value}\""
    '') themeIni}
  '';
}
