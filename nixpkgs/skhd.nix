{ fetchFromGitHub, foldAttrs', lib, merge, prefixFlatten, skhd, wrap }:
with builtins;
with lib;
with rec {
  unlines = concatStringsSep "\n";
  unwords = concatStringsSep " ";

  # Send a set of helper scripts through 'wrap'. To allow scripts to call each
  # other, we take the fixed-point of a set-generating function (i.e. we pass it
  # a 'self' argument).
  helpers = f: mapAttrs (name: script: wrap {
                          inherit name;
                          script = ''
                            #!/usr/bin/env bash
                            set -e
                            ${script}
                          '';
                        })
                        (f (helpers f));
};
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

  skhdConfig =
    with rec {
      # Most of our shortcuts are for yabai, since it's designed to be used
      # in conjunction with a hotkey daemon like skhd.
      yabaiCfg =
        with rec {
          # The spaces we're going to use. Always use these variables, instead
          # of hard-coding, to ensure consistency when changing the number.
          spaces = range 1 9;  # Ignore 0 to avoid off-by-one nonsense
          count  = toString (length spaces);
          labels = map (n: "l${toString n}") spaces;

          # The main 'hotkey' for invoking Yabai actions. Note that this
          # function adds a '-' that skhd expects, so it should come at the end
          # of any other modifiers (e.g. alt or shift)
          mod = k: "lalt - ${k}";

          # Extra modifiers. Note that these don't add the '-' that skhd expects
          # at the end of the modifiers; either use them in conjunction with
          # 'mod' e.g. 'shift (mod "j")' or put '-' explicitly e.g. 'alt "- j"'.
          alt   = k: "alt   + ${k}";
          shift = k: "shift + ${k}";

          # Re-jigs our displays/spaces/etc. to work like XMonad. Specifically:
          #  - We want a fixed number of spaces (destroy/create to enforce this)
          #  - Spaces shouldn't be tied to displays.
          #  - "Switch to space N" should bring that space to the focused
          #    display, rather than changing which display is focused.
          #
          # This would be nice to put in Yabai's startup config, but doesn't
          # seem to work (maybe only "config" options work there?).
          # TODO: Prefer destroying empty spaces, to reduce window shuffling
          fixUpSpaces = wrap {
            name   = "fixUpSpaces";
            vars   = {
              findUnlabelled = wrap {
                name = "findUnlabelled";
                script = ''
                  #!/usr/bin/env bash
                  set -e

                  # Assume we didn't find anything
                  CODE=1

                  # Note: 'label' is a keyword in jq
                  UNLABELLED=$(yabai -m query --spaces | jq '${unwords [
                    "map(select(.label as $l      |"
                                "${toJSON labels} |"
                                "map(. == $l)     |"
                                "any | not))      |"
                    "map(.index)"
                  ]}')
                  if echo "$UNLABELLED" | jq -e 'length | . > 0' > /dev/null
                  then
                    CODE=0
                    echo "$UNLABELLED" | jq '.[]'
                  fi

                  # Look for spaces with duplicate labels
                  ${unlines
                    (map (l: ''
                           if yabai -m query --spaces | jq -e '${unwords [
                             "map(select(.label | . == ${toJSON l} )) |"
                             "length | . > 1"
                           ]}' > /dev/null
                           then
                             # This label is applied to multiple spaces, spit
                             # out the index of one of them (arbitrarily)
                             yabai -m query --spaces | jq '${unwords [
                               "map(select(.label | . == ${toJSON l} )) |"
                               ".[0] | .index"
                             ]}'
                             CODE=0
                           fi
                         '')
                         labels)}

                  # Let other applications know if we found anything
                  # Note that in normal operation we should only be called when
                  # we need to find a space for a label, which implies that
                  # there should be at least one available; hence the warning.
                  [[ "$CODE" -eq 0 ]] ||
                    echo "Warning: Couldn't find spaces with dodgy labels" 1>&2
                  exit "$CODE"
                '';
              };
            };
            script = ''
              #!/usr/bin/env bash
              set -e

              # Ensure we have ${count} spaces in total
              D=$(yabai -m query --spaces |
                  jq 'map(select(.focused == 1)) | .[] | .display')
              while [[ $(yabai -m query --spaces | jq 'length') -gt ${count} ]]
              do
                echo "Need to add more spaces" 1>&2
                # If there's only one space on this display, switch to another
                if [[ $(yabai -m query --spaces --display |
                        jq 'length') -eq 1 ]]
                then
                  echo "Switching display to avoid underpopulation"
                  yabai -m display --focus next || yabai -m display --focus prev
                fi
                yabai -m space --destroy
              done
              yabai -m display --focus "$D" || true
              unset D
              while [[ $(yabai -m query --spaces | jq 'length') -lt ${count} ]]
              do
                echo "Need to create more spaces" 1>&2
                yabai -m space --create
              done

              # Spaces are indexed, but that order can change, e.g. when moving
              # them between displays. We'll use labels instead, since they're
              # more stable: the labels are "l" followed by the current index.
              # These labels should be used by our keybindings, rather than the
              # indices.
              echo "Labelling spaces" 1>&2
              ${unlines (map (n: with { s = toString n; }; ''
                               # Skip this label if a space already has it
                               if yabai -m query --spaces |
                                  jq -e '${unwords [
                                    "map(select(.label == \"l${s}\")) |"
                                    "length | . == 0"
                                  ]}' > /dev/null
                               then
                                 # Find a space with a dodgy or duplicate label.
                                 # If we're here then it must be the case that:
                                 #  - We've got the right number of spaces
                                 #  - There isn't a space with this label
                                 # This implies that there must be a space with
                                 # no label, or a dodgy label, or a duplicate
                                 # label, which findUnlabelled will give us
                                 yabai -m space $($findUnlabelled | head -n1) \
                                       --label l${s} || true
                               fi
                             '')
                             spaces)}
            '';
          };

          # Force all Emacs windows to be "zoomed", i.e. take up their whole
          # space. Since Emacs doesn't tile nicely, this at least resizes it
          # to fit its current display.
          fixUpEmacs = wrap {
            name   = "fixUpEmacs";
            script = ''
              #!/usr/bin/env bash
              set -e
              osascript -e 'tell application "Emacs"
                              repeat with x from 1 to (count windows)
                                tell window x
                                  set zoomed to true
                                end tell
                              end repeat
                            end tell'
            '';
          };
        };
        merge [
          # Focusing and moving windows. If we hit either end of the window
          # list, roll over to the other.
          {
            "${       mod "j" }" = "yabai -m window --focus next || " +
                                   "yabai -m window --focus first";
            "${       mod "k" }" = "yabai -m window --focus prev || " +
                                   "yabai -m window --focus last";
            "${shift (mod "j")}" = "yabai -m window --swap  next || " +
                                   "yabai -m window --swap  first";
            "${shift (mod "k")}" = "yabai -m window --swap  prev || " +
                                   "yabai -m window --swap  last";
          }

          # Hotkeys for switching to a particular space (by label)
          (with helpers (self: {
            # If our spaces aren't labelled, something is up
            maybeFixSpaces = ''
              if yabai -m query --spaces | jq -e 'map(.label) | sort | . != ${
                toJSON (map (n: "l${toString n}") spaces)
              }' > /dev/null
              then
                echo "Fixing up spaces first" 1>&2
                ${fixUpSpaces}
              fi
              true
            '';

            # Picks a display with more than 2 spaces (guaranteed since we have
            # fewer than 5 displays!)
            pickGreedyDisplay = ''
              yabai -m query --displays |
                jq 'map(select(.spaces | length | . > 2)) | .[] | .index' |
                head -n1
            '';

            # Find a non-visible space from a display with many spaces
            pickInvisibleSpace = ''
              yabai -m query --spaces --display $(${self.pickGreedyDisplay}) |
                jq 'map(select(.visible | . == 0)) | .[] | .index' |
                head -n1
            '';

            # Make sure each display has at least two spaces, so we can move one
            ensureDisplaysHaveSpaces = ''
              # Loop through display indices which have fewer than 2 spaces
              yabai -m query --displays |
                jq 'map(select(.spaces | length | . < 2)) | .[] | .index' |
                while read -r D
                do
                  echo "Display $D is low on spaces, moving one over" 1>&2
                  yabai -m space $(${self.pickInvisibleSpace}) --display $D ||
                    true
                done
            '';

            # Get the focused display (the display of the focused space)
            focusedDisplay = ''
              yabai -m query --spaces |
                jq 'map(select(.focused | . == 1)) | .[] | .display'
            '';

            forceSpaceFocus = ''
                # Move the desired space to the focused display
                TRIES=0
                while true
                do
                  if [[ "$TRIES" -gt 5 ]]
                  then
                    echo "Failed to move $1 to the focused display" 1>&2
                    break
                  fi

                  D=$(${self.focusedDisplay})
                  yabai -m query --spaces | jq -e "${unwords [
                    "map(select(.label == \\\"$1\\\")) |"
                    ".[] | .display == $D"
                  ]}" > /dev/null && break

                  yabai -m space $1 --display $D || true
                  sleep 0.1
                done

                # Focus this space, if needed. This loop serves two purposes:
                #  - Don't bother switching if we're already focused
                #  - If it doesn't switch for some reason (I've experienced this
                #    before) retry a few times before giving up
                TRIES=0
                while yabai -m query --spaces | jq -e "${unwords [
                        "map(select(.label == \\\"$1\\\")) |"
                        ".[] | .focused == 0"
                      ]}" > /dev/null
                do
                  TRIES=$(( TRIES + 1 ))
                  if [[ "$TRIES" -gt 5 ]]
                  then
                    echo "Giving up focusing $1!" 1>&2
                    break
                  fi
                  if [[ "$TRIES" -gt 1 ]]
                  then
                    echo "Struggling to focus $1" 1>&2
                    # Try switching to something else, see if that rejigs it?
                    yabai -m space --focus next || yabai -m space --focus first
                  fi

                  yabai -m space --focus $1 || true
                  sleep 0.1
                done
            '';
          });
          listToAttrs (map (n: with { s = toString n; }; {
                             name  = mod s;
                             value = unwords [
                               "${maybeFixSpaces};"
                               "${ensureDisplaysHaveSpaces};"
                               "${forceSpaceFocus} l${s}"
                             ];
                           })
                           spaces))

          # Send focused window to a particular space (by label)
          (listToAttrs (map (n: {
                              name  = shift (mod (toString n));
                              value = "yabai -m window --space l${toString n}";
                            })
                            spaces))

          # Switch between displays, cycling around when we hit the end of list
          {
            "${mod "left" }" = "yabai -m display --focus prev || " +
                               "yabai -m display --focus last";
            "${mod "right"}" = "yabai -m display --focus next || " +
                               "yabai -m display --focus first";
          }

          # General commands
          {
            "${       mod "space"}" = "yabai -m window --toggle split";
            "${       mod "f"    }" = "yabai -m window --toggle zoom-parent";
            "${shift (mod "c")   }" = "yabai -m window --close";

            # Treat "west" area like XMonad's "main" area
            "${mod "return"}" = "yabai -m window --swap west";

            # Force a re-jig of spaces
            "${mod "r"}" = "${fixUpSpaces}";
            "${mod "e"}" = "${fixUpEmacs }";

            # Tile/float the focused window
            # TODO: Add queries so they only do one or the other
            "${       mod "t" }" = "yabai -m window --toggle float";
            "${shift (mod "t")}" = "yabai -m window --toggle float";
          }

          # Window resizing (emulates XMonad)
          {
            # Vertical resizing is easy: just change where the bottom is
            "${mod "i"}" = "yabai -m window --resize bottom:0:-60";
            "${mod "o"}" = "yabai -m window --resize bottom:0:60";

            # Horizontal requires offset calculations
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
          }

          /*
            # balance size of windows; write explicitly to get +/- right
            #yabai -m space --balance = "shift + alt - 0";

            yabai -m space --focus = {
              "yabai -m space --focus recent" = mod "tab";
              "yabai -m space --focus prev"   = mod "p";
              "yabai -m space --focus next"   = mod "n";

            };
          };

          # make floating window fill screen
          #yabai -m window --grid "1:1:0:0:1:1" = mod "f";

          # float / unfloat window and center on screen
          #${mod "space :"} = "yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2" = ;
          };*/
        ];
    };
    foldAttrs' (key: cmd: result: result + ''
                 ${key} : ${cmd}
               '')
               ""
               yabaiCfg;
}
