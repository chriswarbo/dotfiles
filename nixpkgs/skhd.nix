{ fetchFromGitHub, foldAttrs', lib, prefixFlatten, skhd }:
with lib;
with { unwords = concatStringsSep " "; };
{
  enable  = true;
  package = skhd.overrideAttrs (old: rec {
    version = "0.3.5";
    src     = fetchFromGitHub {
      owner  = "koekeishiya";
      repo   = "skhd";
      rev    = "v${version}";
      sha256 = "0x099979kgpim18r0vi9vd821qnv0rl3rkj0nd1nx3wljxgf7mrg";
    };
  });

  # TODO: Refactor
  # TODO: Pick more ergonomic keys (remap Option to Super?)
  skhdConfig =
    with rec {
      # The skhd config has the form "keys : commands". Since the commands
      # govern the semantics it makes more sense for us to specify them the
      # other way around.

      possiblyUseful = {
        # launchers
        #"open -nb io.alacritty" = cmd + ctrl - return;
        #"open -b org.gnu.Emacs" = cmd + ctrl - i;

        # make floating window fill left-half of screen
        # "yabai -m window --grid 1:2:0:0:1:1" = shift + alt - left

        # make floating window fill right-half of screen
        # "yabai -m window --grid 1:2:1:0:1:1" = shift + alt - right  :

        # create desktop, move window and follow focus - uses jq for parsing json (brew install jq)
        # shift + cmd - n : yabai -m space --create && \
                          # index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')" && \
                          # yabai -m window --space "''${index}" && \
                          # yabai -m space --focus "''${index}"

        # create desktop and follow focus - uses jq for parsing json (brew install jq)
        # cmd + alt - n : yabai -m space --create && \
        #                 index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')" && \
        #                 yabai -m space --focus "''${index}"

        # destroy desktop
        # cmd + alt - w : yabai -m space --destroy

        # focus monitor
        # TODO: [Darwin](skhd/yabai) Directional monitor focus
        #       yabai's API provides display position offsets.
        #       yabai -m query --displays | jq
        # ctrl + alt - x  : yabai -m display --focus recent
        # ctrl + alt - z  : yabai -m display --focus prev
        # ctrl + alt - c  : yabai -m display --focus next
        # ctrl + alt - 1  : yabai -m display --focus 1
        # ctrl + alt - 2  : yabai -m display --focus 2
        # ctrl + alt - 3  : yabai -m display --focus 3

        # send window to monitor and follow focus
        # ctrl + cmd - x  : yabai -m window --display recent; yabai -m display --focus recent
        # ctrl + cmd - z  : yabai -m window --display prev; yabai -m display --focus prev
        # ctrl + cmd - c  : yabai -m window --display next; yabai -m display --focus next
        # ctrl + cmd - 1  : yabai -m window --display 1; yabai -m display --focus 1
        # ctrl + cmd - 2  : yabai -m window --display 2; yabai -m display --focus 2
        # ctrl + cmd - 3  : yabai -m window --display 3; yabai -m display --focus 3

        # # change layout of desktop
        # ctrl + alt - a : yabai -m space --layout bsp
        # ctrl + alt - d : yabai -m space --layout float
      };

      # Most of our shortcuts are for yabai, since it's designed to be used
      # in conjunction with a hotkey daemon like skhd.
      yabaiCfg =
        with {
          # The main 'hotkey' for invoking Yabai actions. Note that this
          # function adds a '-' that skhd expects, so it should come at the end
          # of any other modifiers (e.g. alt or shift)
          mod = k: "lalt - ${k}";

          # Extra modifiers. Note that these don't add the '-' that skhd expects
          # at the end of the modifiers; either use them in conjunction with
          # 'mod' e.g. 'shift (mod "j")' or put '-' explicitly e.g. 'alt "- j"'.
          alt   = k: "alt   + ${k}";
          shift = k: "shift + ${k}";
        };
        {
          # Cycle focus between windows in this space. If we run out, roll over
          # to the other "end"
          "${mod "j"}" = "yabai -m window --focus next || yabai -m window --focus first";
          "${mod "k"}" = "yabai -m window --focus prev || yabai -m window --focus last";

          # Change window order
          "${shift (mod "j")}" = "yabai -m window --swap next";
          "${shift (mod "k")}" = "yabai -m window --swap prev";

          # Hotkeys for switching to a particular space
          "${mod "1"}" = "yabai -m space --focus 1" ;
          "${mod "2"}" = "yabai -m space --focus 2" ;
          "${mod "3"}" = "yabai -m space --focus 3" ;
          "${mod "4"}" = "yabai -m space --focus 4" ;
          "${mod "5"}" = "yabai -m space --focus 5" ;
          "${mod "6"}" = "yabai -m space --focus 6" ;
          "${mod "7"}" = "yabai -m space --focus 7" ;
          "${mod "8"}" = "yabai -m space --focus 8" ;
          "${mod "9"}" = "yabai -m space --focus 9" ;
          "${mod "0"}" = "yabai -m space --focus 10";

          # Send focused window to a particular space
          "${shift (mod "1")}" = "yabai -m window recent --space 1" ;
          "${shift (mod "2")}" = "yabai -m window recent --space 2" ;
          "${shift (mod "3")}" = "yabai -m window recent --space 3" ;
          "${shift (mod "4")}" = "yabai -m window recent --space 4" ;
          "${shift (mod "5")}" = "yabai -m window recent --space 5" ;
          "${shift (mod "6")}" = "yabai -m window recent --space 6" ;
          "${shift (mod "7")}" = "yabai -m window recent --space 7" ;
          "${shift (mod "8")}" = "yabai -m window recent --space 8" ;
          "${shift (mod "9")}" = "yabai -m window recent --space 9" ;
          "${shift (mod "0")}" = "yabai -m window recent --space 10";

          # Switch between displays
          "${mod "left" }" = "yabai -m display prev";
          "${mod "right"}" = "yabai -m display next";

          # Treat "west" area like XMonad's "main" area
          "${mod "return"}" = "yabai -m window --swap west";

          "${mod "space"}" = "yabai -m window --toggle split";

          # Look up window size and change it (emulate XMonad)
          "${mod "h"}" = unwords [
            "expr $(yabai -m query --windows --window | jq .frame.x) \\< 20"
            "&&"
            "yabai -m window --resize right:-60:0"
            "||"
            "yabai -m window --resize left:-60:0"
          ];
          "${mod "l"}" = unwords [
            "expr $(yabai -m query --windows --window | jq .frame.x) \\< 20"
            "&&"
            "yabai -m window --resize right:60:0"
            "||"
            "yabai -m window --resize left:60:0"
          ];

          # Vertical resizing is easier: just change where the bottom is
          "${mod "i"}" = "yabai -m window --resize bottom:0:-60";
          "${mod "o"}" = "yabai -m window --resize bottom:0:60";

          /*
            # balance size of windows; write explicitly to get +/- right
            #yabai -m space --balance = "shift + alt - 0";

            yabai -m space --focus = {
              "yabai -m space --focus recent" = mod "tab";
              "yabai -m space --focus prev"   = mod "p";
              "yabai -m space --focus next"   = mod "n";

            };
          };

          "yabai -m window --focus west"  = mod "h";
          "yabai -m window --focus south" = mod "j";
          "yabai -m window --focus north" = mod "k";
          "yabai -m window --focus east"  = mod "l";

          # make floating window fill screen
          #yabai -m window --grid "1:1:0:0:1:1" = mod "f";

          # set insertion point in focused container
          "yabai -m window --insert west"  = alt (mod "h");
          "yabai -m window --insert south" = alt (mod "j");
          "yabai -m window --insert north" = alt (mod "k");
          "yabai -m window --insert east"  = alt (mod "l");

          # send window to desktop and follow focus
          "yabai -m window --space recent; yabai -m space --focus recent" = shift (mod "tab");
          "yabai -m window --space prev  ; yabai -m space --focus prev"   = shift (mod "p"  );
          "yabai -m window --space next  ; yabai -m space --focus next"   = shift (mod "n"  );
          "yabai -m window --space 1     ; yabai -m space --focus 1"      = shift (mod "1"  );
          "yabai -m window --space 2     ; yabai -m space --focus 2"      = shift (mod "2"  );
          "yabai -m window --space 3     ; yabai -m space --focus 3"      = shift (mod "3"  );
          "yabai -m window --space 4     ; yabai -m space --focus 4"      = shift (mod "4"  );
          "yabai -m window --space 5     ; yabai -m space --focus 5"      = shift (mod "5"  );
          "yabai -m window --space 6     ; yabai -m space --focus 6"      = shift (mod "6"  );
          "yabai -m window --space 7     ; yabai -m space --focus 7"      = shift (mod "7"  );
          "yabai -m window --space 8     ; yabai -m space --focus 8"      = shift (mod "8"  );
          "yabai -m window --space 9     ; yabai -m space --focus 9"      = shift (mod "9"  );
          "yabai -m window --space 10    ; yabai -m space --focus 10"     = shift (mod "0"  );

          # float / unfloat window and center on screen
          #${mod "space :"} = "yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2" = ;
          };*/
        };
    };
    foldAttrs' (key: cmd: result: result + ''
                 ${key} : ${cmd}
               '')
               ""
               yabaiCfg;
}
