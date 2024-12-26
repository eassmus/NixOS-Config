{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    font-awesome 
    jetbrains-mono
    hanazono
    noto-fonts
    noto-fonts-extra
    noto-fonts-cjk-sans

    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

fonts.fontconfig.defaultFonts = {
    monospace = [
	"JetBrainsMono Nerd Font Mono"
	"Noto Sans Mono CJK SC"
	"Noto Sans Mono CJK TC"
    ];
#fc-list : family | grep 'Sans CJK'
    sansSerif = [
	"DejaVu Sans"
	"Noto Sans CJK SC"
	"Noto Sans CJK TC"
    ];
# fc-list : family | grep 'Serif CJK'
    serif = [
	"DejaVu Serif"
	"Noto Serif CJK SC"
	"Noto Serif CJK TC"
    ];
};
}
