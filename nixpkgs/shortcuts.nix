# Commands to invoke when we press hot keys. These are mostly for controlling
# the Yabai window manager.
{ attrsToDirs', callPackage, lib, wrap }:

with builtins;
with lib;
with rec {
  # The spaces we're going to use. Always use these variables, instead
  # of hard-coding, to ensure consistency when changing the number.
  spaces = range 1 9;  # Ignore 0 to avoid off-by-one nonsense

  # All of our scripts use bash with stricter error checking
  makeScript = name: script: wrap {
    inherit name;
    script = ''
      #!/usr/bin/env bash
      set -e
      ${script}
    '';
  };

  # The commands we'll write out into the resulting package. This is defined as
  # a function taking a 'self' argument, so scripts can refer to other scripts.
  # This ensures infinite recursion is caught at build time, and makes sure we
  # don't mis-spell any of our commands.
  makeCommands = self: mapAttrs makeScript {

    # Switch to displays and spaces. These are flaky, so we retry multiple times
    # and, if it keeps failing, we do some random switching around in the hope
    # that it un-sticks itself.

    # General commands
    #"${       mod "f"    }" = "yabai -m window --toggle zoom-parent";

    fix-up-emacs = ''
      # Force all Emacs windows to be "zoomed", i.e. take up their whole
      # space. Since Emacs doesn't tile nicely, this at least resizes it
      # to fit its current display.

      osascript -e 'tell application "Emacs"
                      repeat with x from 1 to (count windows)
                        tell window x
                          set zoomed to true
                        end tell
                      end repeat
                    end tell'
    '';

    # Tile/float the focused window
    # TODO: Add queries so they only do one or the other
    # "${       mod "t" }" = "yabai -m window --toggle float";
    # "${shift (mod "t")}" = "yabai -m window --toggle float";

    # Window resizing (emulates XMonad)
    # Vertical resizing is easy: just change where the bottom is
    shrink-vert = "yabai -m window --resize bottom:0:-60";
    grow-vert   = "yabai -m window --resize bottom:0:60";

    # Horizontal requires offset calculations
    shrink-horiz = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:-60:0
      else
        yabai -m window --resize left:-60:0
      fi
    '';
    grow-horiz = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:60:0
      else
        yabai -m window --resize left:60:0
      fi
    '';

    # Switch to the space with the given label. Make sure it exists first, and
    # bring it to the current display if it isn't already.
    switch-to = ''
      LABEL="$1" ${haskellCommands.focusHereEnv}
    '';

    move-window  = ''
      D=$(${haskellCommands.currentDisplay})
      yabai -m window  --space "$1"; sleep 0.1
      yabai -m display --focus "$D"
    '';

    close-window = ''yabai -m window --close       '';
    make-main    = ''yabai -m window --swap   west '';
    toggle-split = ''yabai -m window --toggle split'';
  };

  # Tie the knot, so 'self' works
  shellCommands = makeCommands shellCommands;

  y-monad-src = <home/repos/y-monad>;

  y-monad = callPackage y-monad-src { inherit spaces; };

  haskellCommands = y-monad.commands;
};
rec {
  inherit spaces;
  commands = shellCommands // haskellCommands;

  # Make the commands available as a package, so we can invoke them manually
  package = attrsToDirs' "shortcuts" {
    bin = { shortcuts = commands; };
  };
}
