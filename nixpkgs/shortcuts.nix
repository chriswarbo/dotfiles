# Commands to invoke when we press hot keys. These are mostly for controlling
# the Yabai window manager.
{ attrsToDirs', lib, wrap, writeScript }:

with builtins;
with lib;
with rec {
  # The spaces we're going to use. Always use these variables, instead
  # of hard-coding, to ensure consistency when changing the number.
  spaces = range 1 9;  # Ignore 0 to avoid off-by-one nonsense
  count  = toString (length spaces);
  labels = map (n: "l${toString n}") spaces;

  labelFile = writeScript "workspace-labels" (unlines labels);

  unlines = concatStringsSep "\n";
  unwords = concatStringsSep " ";

  info  = str: ''echo "info: ${str}" 1>&2'';
  debug = str: ''[[ -z "$DEBUG" ]] || echo "debug: ${str}" 1>&2'';
  error = str: ''echo "error: ${str}" 1>&2'';
  fatal = str: error str + ''; echo "Fatal error, aborting" 1>&2; exit 1'';

  makeScript = name: script: wrap {
    inherit name;
    script = ''
      #!/usr/bin/env bash
      set -e
      ${script}
    '';
  };

  makeCommands = self: mapAttrs makeScript {
    # Common queries
    display-count = "yabai -m query --displays | jq 'length'";

    plugged-in = "[[ $(${self.display-count}) -gt 1 ]]";

    current-display = ''
      yabai -m query --spaces |
        jq 'map(select(.focused == 1)) | .[] | .display'
    '';

    display-of-space = ''
      yabai -m query --spaces |
        jq --arg l "$1" 'map(select(.label == $l)) | .[] | .display'
    '';

    space-on-display = ''
      [[ $(${self.display-of-space} "$1") -eq "$2" ]]
    '';

    index-of-space = ''
      yabai -m query --spaces |
        jq --arg l "$1" 'map(select(.label == $l)) | .[] | .index'
    '';

    label-at-index = ''
      yabai -m query --spaces |
        jq --arg i "$1" 'map(select(.index == $i)) | .[] | .label'
    '';

    space-exists = ''
      yabai -m query --spaces |
        jq -e --arg l "$1" 'map(select(.label == $l)) | length | . > 0' \
        > /dev/null
    '';

    space-index-exists = ''
      yabai -m query --spaces |
        jq -e --arg i "$1" 'map(select(.index == $i)) | length | . > 0' \
        > /dev/null
    '';

    current-space = ''
      yabai -m query --spaces |
        jq -r 'map(select(.focused | . == 1)) | .[] | .label'
    '';

    space-is-visible = ''
      yabai -m query --spaces |
        jq -e --arg l "$1" 'map(select(.label == $l)) | .[] | .visible == 1' \
        > /dev/null
    '';

    number-from-label = ''
      echo "$1" | grep -o '[0-9]*'
    '';

    space-has-index = ''
      [[ $(${self.index-of-space} "$1") -eq "$2" ]]
    '';

    space-index-matches = ''
      N=$(${self.number-from-label} "$1")
      ${self.space-has-index} "$1" "$N"
    '';

    current-window = ''
      yabai -m query --windows |
        jq -r 'map(select(.focused == 1)) | .[] | .id'
    '';

    space-of-window = ''
      I=$(yabai -m query --windows |
            jq --argjson w "$1" 'map(select(.id == $w)) | .[] | .space')
      yabai -m query --spaces |
        jq -r --argjson i "$I" 'map(select(.index == $i) | .label) | .[]'
    '';

    # Helper scripts

    store-currently-visible = ''
      # We can fiddle with spaces as much as we like, as long as:
      #  - The 'visible' space on each display remains on the same display
      #  - The 'visible' space on each display remains visible
      #  - The 'focused' display remains focused
      #  - The 'focused' space remains focused
      #
      # This script dumps out all of that information to stdout, so it can be
      # restored by other scripts (selectively, since the whole point of our
      # scripts is that they change some things)
      VISIBLE=$(yabai -m query --spaces |
                jq 'map(select(.visible == 1) | .label)')

      DISPLAYS=$(yabai -m query --spaces |
                 jq 'map(select(.visible == 1) |${""
                         } {"key": .label, "value": .display}) | from_entries')

      FOCUSED_DISPLAY=$(${self.current-display})
      FOCUSED_SPACE=$(${self.current-space} | jq -R '.')

      jq -n --argjson visible  "$VISIBLE"         \
            --argjson displays "$DISPLAYS"        \
            --argjson fdisplay "$FOCUSED_DISPLAY" \
            --argjson fspace   "$FOCUSED_SPACE"   \
            '{"visible": {"spaces": $visible, "displays": $displays}, ${""
             }"focused": {"space" : $fspace,  "display" : $fdisplay}}'
    '';

    restore-visible-to-displays = ''
      # Reads in the output of self.store-currently-visible and puts the
      # previously visible spaces back on their original displays
      DATA=$(cat)
      echo "$DATA" | jq -r '.visible | .spaces | .[]' | while read -r L
      do
        D=$(echo "$DATA" | jq --arg l "$L" '.visible | .displays | .[$l]')
        ${debug "Putting previously-visible space $L back on display $D"}
        ${self.move-space-to-display} "$L" "$D"
      done
    '';

    restore-focused-space = ''
      # Reads in the output of self.store-currently-visible and tries to focus
      # the previously-focused space; on whichever display it is currently on.

      # Get the label of the space we need to focus
      DATA=$(cat)
      L=$(echo "$DATA" | jq -r '.focused | .space')

      # Switch to that space's display, if we're not currently there
      D=$(${self.display-of-space} "$L")
      [[ "$(${self.current-display})" -eq "$D" ]] ||
        yabai -m display --focus "$D"

      # Ensure the previously focused space is currently focused
      [[ "$(${self.current-space})"   -eq "$L" ]] ||
        yabai -m space   --focus "$L"
    '';

    restore-visible-spaces = ''
      # Reads in the output of self.store-currently-visible and tries to ensure
      # that the previously visible spaces are still visible. Note that this
      # might not be possible, if some have been moved to the same display. In
      # these cases we prefer to display the previously-focused space.
      #
      # If you want these spaces back on the same display as well, use
      # self.restore-visible-to-displays first, then this.

      # Focus each of the previously-visible spaces:
      #  1) If they've not changed displays, then we will get one per display,
      #     as before.
      #  2) If their displays have changed, but there's still one per display,
      #     then they'll all be visible (but on different displays than before)
      #  3) If they've moved on to the same display then only one of them will
      #     become visible (arbitrarily), whilst the other display will continue
      #     to show whatever it had before this script started.
      DATA=$(cat)
      echo "$DATA" | jq -r '.visible | .spaces | .[]' | while read -r L
      do
        ${self.focus-space} "$L"
      done

      # We now focus the originally-focused display. We only do this such that
      # in scenario (3) we'll definitely end up with the previously-focused
      # space being visible (otherwise we might get a different
      # previously-visible which happens to now be on the same display).
      #
      # This doesn't affect visibility in the other two scenarios, so we don't
      # care. The focus may change, but this script makes no guarantees about
      # that anyway, so it's fine (i.e. if you want a particular space to be
      # focused after running this script, you need to do that yourself)
      echo "$DATA" | ${self.restore-focused-space}
    '';

    shift-space-to-index = ''
      while [[ $(${self.index-of-space} "$1") -gt "$2" ]]
      do
        yabai -m space "$1" --move prev
      done
      while [[ $(${self.index-of-space} "$1") -lt "$2" ]]
      do
        yabai -m space "$1" --move next
      done
    '';

    shift-space-to-matching-index = ''
      I=$(echo "$1" | grep -o '[0-9]*')
      ${self.shift-space-to-index} "$1" "$I"
    '';

    focus-display = ''
      ${self.lax-spaces-are-set-up} focus-display

      ${debug "focus-display: Focusing $1"}
      COUNT=0
      while [[ $(${self.current-display}) -ne $1 ]]
      do
        ${debug "focus-display: On display $(${self.current-display})"}
        if [[ "$COUNT" -gt 10 ]]
        then
          ${fatal "focus-display: Failed to switch to display $1"}
        fi

        if [[ "$COUNT" -lt 4 ]]
        then
          yabai -m display --focus "$1"
        else
          yabai -m display --focus next
        fi
        sleep 0.2
        COUNT=$(( COUNT + 1 ))
      done

      D=$(${self.current-display})
      if [[ "$D" -eq "$1" ]]
      then
        ${debug "focus-display: Switched focus to display $1"}
      else
        ${fatal "focus-display: Should be on $1, actually on $D"}
      fi
      exit 0
    '';

    focus-space = ''
      ${self.lax-spaces-are-set-up} focus-space

      if ! ${self.space-exists} "$1"
      then
        ${fatal "focus-space: Asked to focus space $1, which doesn't exist"}
      fi

      S1=$(${self.current-space})
      ${debug "focus-space: We're on space $S1, asked to focus $1"}

      # Focus the display of the given space
      ${self.focus-display} "$(${self.display-of-space} "$1")"

      # Focus the given space, if it's not already
      COUNT=0
      while ! [[ "x$(${self.current-space})" = "x$1" ]]
      do
        if [[ "$COUNT" -gt 30 ]]
        then
          ${fatal "focus-space: Couldn't get space $1 focused"}
        fi

        if [[ $(( COUNT % 10 )) -eq 9 ]]
        then
          ${self.display-prev}; sleep 0.2
          ${self.display-next}; sleep 0.2
        fi

        if [[ $(( COUNT % 15 )) -eq 4 ]]
        then
          yabai   -m space --focus next  2>/dev/null ||
            yabai -m space --focus first
        fi

        if [[ "$COUNT" -gt 3 ]]
        then
          R=$(${self.pick-existing-space})
          ${debug "focus-space: Struggling to focus; trying from $R"}
          yabai -m space --focus "$R"
          sleep 0.2
        fi

        ${debug "focus-space: $(${self.current-space}) focused; focusing $1"}
        yabai -m space --focus "$1"
        sleep 0.2
        COUNT=$(( COUNT + 1 ))
      done

      S3=$(${self.current-space})
      if [[ "x$S3" = "x$1" ]]
      then
        ${debug "focus-space: Successfully focused space $1"}
      else
        ${fatal "focus-space: Should've focused space $1, we're on $S3"}
      fi
      exit 0
    '';

    find-unlabelled = ''
      # Assume we didn't find anything
      CODE=1

      SPACES=$(yabai -m query --spaces)

      # Note: 'label' is a keyword in jq
      UNLABELLED=$(echo "$SPACES" | jq '${unwords [
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
               if echo "$SPACES" | jq -e '${unwords [
                 "map(select(.label | . == ${toJSON l} )) |"
                 "length | . > 1"
               ]}' > /dev/null
               then
                 # This label is applied to multiple spaces, spit
                 # out the index of one of them (arbitrarily)
                 echo "$SPACES" | jq '${unwords [
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

    # Destroy spaces if we have too many, create if we don't have enough
    populate-spaces = ''
      # Ensure we have ${count} spaces in total
      SPACES=$(yabai -m query --spaces)
      D=$(echo "$SPACES" |
          jq 'map(select(.focused == 1)) | .[] | .display')
      SWITCHED=0
      while [[ $(echo "$SPACES" | jq 'length') -gt ${count} ]]
      do
        echo "Need to add more spaces" 1>&2
        # If there's only one space on this display, switch to another
        if [[ $(yabai -m query --spaces --display |
                jq 'length') -eq 1 ]]
        then
          echo "Switching display to avoid underpopulation" 1>&2
          SWITCHED=1
          yabai   -m display --focus next ||
            yabai -m display --focus first
        fi
        yabai -m space --destroy || true
        SPACES=$(yabai -m query --spaces)
      done
      [[ "$SWITCHED" -eq 0 ]] || yabai -m display --focus "$D" || true
      unset D
      unset SWITCHED

      if [[ $(echo "$SPACES" | jq 'length') -lt ${count} ]]
      then
        echo "Need to create more spaces" 1>&2
        for N in seq 1 $(echo "$SPACES" | jq 'length | ${count} - .')
        do
          yabai -m space --create || true
        done
        SPACES=$(yabai -m query --spaces)
      fi
    '';

    fix-up-spaces = ''
      # Re-jigs our displays/spaces/etc. to work like XMonad. Specifically:
      #  - We want a fixed number of spaces (destroy/create to enforce this)
      #  - "Switch to space N" should bring that space to the focused
      #    display, rather than changing which display is focused.
      #
      # This would be nice to put in Yabai's startup config, but doesn't
      # seem to work (maybe only "config" options work there?).
      # TODO: Prefer destroying empty spaces, to reduce window shuffling

      ${self.populate-spaces}
      ${self.label-spaces}
    '';

    label-spaces = ''
      # Spaces are indexed, but that order can change, e.g. when moving
      # them between displays. We'll use labels instead, since they're
      # more stable: the labels are "l" followed by the current index.
      # These labels should be used by our keybindings, rather than the
      # indices.
      function info {
        [[ -z "$DEBUG" ]] || echo "label-spaces: $@" 1>&2
      }

      ${unlines (map (n: with { s = toString n; }; ''
                       # Skip this label if a space already has it
                       info "Checking if a space is already labelled l${s}"
                       SPACES=$(yabai -m query --spaces)
                       if echo "$SPACES" |
                          jq -e 'map(select(.label == "l${s}")) | ${""
                                 } length | . == 0' > /dev/null
                       then
                         info "Labelling space l${s}"
                         # Find a space with a dodgy or duplicate label.
                         # If we're here then it must be the case that:
                         #  - We've got the right number of spaces
                         #  - There isn't a space with this label
                         # This implies that there must be a space with
                         # no label, or a dodgy label, or a duplicate
                         # label, which self.find-unlabelled will
                         # give us
                         if UL=$(${self.find-unlabelled})
                         then
                           info "Found unlabelled spaces for l${s}: $UL"
                           yabai -m space "$(echo "$UL" | head -n1)" \
                                 --label l${s} || true
                         else
                           echo "label-spaces: No unlabelled spaces!" 1>&2
                         fi
                         SPACES=$(yabai -m query --spaces)
                       else
                         info "Space l${s} already exists, nothing to do"
                       fi
                     '')
                     spaces)}
    '';

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

    arrange-spaces = ''
      # To minimise disruption if/when Yabai dies, we can use this script to
      # arrange spaces in order of their labels. This way, relabelling them
      # should result in no changes, and hence no need to move windows.

      # macOS numbers spaces on one display then another, and so on.
      # This means that, for example, l1 will be out of order if it's on
      # display 2; since whatever space(s) is on display 1 will come
      # first. The same applies to the last space having to be on the
      # highest-numbered display.
      # Note that Yabai's display numbering *seems* to correspond to
      # that of macOS, at least on my setup. This assumption might be
      # wrong!

      function info {
        [[ -z "$DEBUG" ]] || echo "arrange-spaces: $@" 1>&2
      }

      function indexOf {
        yabai -m query --spaces |
          jq "map(select(.label == \"$1\")) | .[] | .index"
      }

      function displayOf {
        yabai -m query --spaces |
          jq "map(select(.label == \"$1\")) | .[] | .display"
      }

      function spacesInOrder {
        info "Checking if spaces are in order"
        SPACES=$(yabai -m query --spaces)
        for N in ${unwords (map toString spaces)}
        do
          info "Checking space $N"
          [[ $(indexOf "l$N") -eq "$N" ]] || return 1
          info "Space $N is in the correct place"
        done
        info "All spaces are in the correct place"
        return 0
      }

      info "Ensuring spaces are labelled first"
      ${self.fix-up-spaces}

      # Evenly distribute spaces across displays (easier to have a fixed
      # target than enforce constraints on some arbitrary arrangement)
      # TODO: Hardcoded to 2 displays at the moment.
      DCOUNT=$(yabai -m query --displays | jq 'length')
      info "Found $DCOUNT displays"
      [[ "$DCOUNT" -lt 3 ]] || {
        echo "Found $DCOUNT displays; we can only handle 1 or 2" 1>&2
        exit 1
      }
      if [[ "$DCOUNT" -gt 1 ]]
      then
        info "External display is plugged in; we assume it's index 2"
        for M in ${unwords (map toString spaces)}
        do
          if [[ "$M" -lt $(( ${count} / 2 )) ]]
          then
            D=1
          else
            D=2
          fi
          DM=$(displayOf "l$M")
          info "Ensuring space $M is on display $D; it's on $DM"
          if [[ "$DM" -ne "$D" ]]
          then
            info "Moving space $M from display $DM to display $D"
            yabai -m space "l$M" --display "$D"
          fi
        done
      fi

      # Rearrange spaces in order of labels
      for D in $(seq 1 "$DCOUNT")
      do
        while ! spacesInOrder
        do
          for M in ${unwords (map toString spaces)}
          do
            # We only execute a movement half the time; the randomness
            # should prevent us getting stuck in a loop
            if [[ $(indexOf "l$M") -lt "$M" ]]
            then
              [[ $(( RANDOM % 2 )) -eq 0 ]] ||
                yabai -m space "l$M" --move next
            fi

            if [[ $(indexOf "l$M") -gt "$M" ]]
            then
              [[ $(( RANDOM % 2 )) -eq 0 ]] ||
                yabai -m space "l$M" --move prev
            fi
          done
        done
      done
    '';

    # General commands
    #"${       mod "f"    }" = "yabai -m window --toggle zoom-parent";

    # mod-r
    force-rejig = ''
      ${self.arrange-spaces}
      pkill yabai || true
      sleep 2
      ${self.fix-up-spaces}
      pkill skhd || true
    '';

    # Tile/float the focused window
    # TODO: Add queries so they only do one or the other
    # "${       mod "t" }" = "yabai -m window --toggle float";
    # "${shift (mod "t")}" = "yabai -m window --toggle float";

    # Window resizing (emulates XMonad)
    # Vertical resizing is easy: just change where the bottom is
    # "${mod "i"}" = "yabai -m window --resize bottom:0:-60";
    # "${mod "o"}" = "yabai -m window --resize bottom:0:60";

    # Horizontal requires offset calculations
    # mod-h
    resize-left = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:-60:0
      else
        yabai -m window --resize left:-60:0
      fi
    '';
    # mod-l
    resize-right = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:60:0
      else
        yabai -m window --resize left:60:0
      fi
    '';

    # If our spaces aren't labelled, something is up
    maybe-fix-spaces = ''
      if yabai -m query --spaces | jq -e 'map(.label) | sort | . != ${
        toJSON (map (n: "l${toString n}") spaces)
      }' > /dev/null
      then
        echo "Fixing up spaces first" 1>&2
        ${self.fix-up-spaces}
      fi
      true
    '';

    # Picks a display with more than 2 spaces (guaranteed since we have
    # fewer than 5 displays!)
    pick-greedy-display = ''
      yabai -m query --displays |
        jq 'map(select(.spaces | length | . > 2)) | .[] | .index' |
        head -n1
    '';

    # Find a non-visible space from a display with many spaces
    pick-invisible-space = ''
      D=$(${self.pick-greedy-display})
      yabai -m query --spaces --display "$D" |
        jq 'map(select(.visible | . == 0)) | .[] | .index' |
        head -n1
    '';

    # Make sure each display has at least two spaces, so we can move one
    ensure-displays-have-spaces = ''
      # Loop through display indices which have fewer than 2 spaces
      while true
      do
        DS=$(yabai -m query --displays)
        echo "$DS" |
          jq -e 'map(select(.spaces | length | . < 2)) | . == []' > /dev/null &&
          break
        echo "$DS" |
          jq 'map(select(.spaces | length | . < 2)) | .[] | .index' |
          while read -r D
          do
            echo "Display $D is low on spaces, moving one over" 1>&2
            S=$(${self.pick-invisible-space})
            yabai -m space "$S" --display "$D" || true
            sleep 0.2
          done
      done
    '';

    # Get the focused display (the display of the focused space)
    focused-display = ''
      yabai -m query --spaces |
        jq 'map(select(.focused | . == 1)) | .[] | .display'
    '';

    force-space-focus = ''
        for RETRY in $(seq 1 10)
        do
          SPACES=$(yabai -m query --spaces)

          # Break if we're focused
          echo "$SPACES" | jq -e "${unwords [
            "map(select(.label == \\\"$1\\\")) |"
            ".[] | .focused == 0"
          ]}" > /dev/null || break

          # Move the desired space to the focused display
          D=$(${self.focused-display})
          if echo "$SPACES" | jq -e "${unwords [
               "map(select(.label == \\\"$1\\\")) |"
               ".[] | .display != $D"
             ]}" > /dev/null
          then
            echo "Moving $1 to display $D"
            yabai -m space $1 --display $D || true
            sleep 0.1

            # Restart the loop, to retry this step until it works
            continue
          fi

          # Focus this space
          yabai -m space --focus $1 || true
          sleep 0.1
        done
    '';

    # Switch to the space with the given label. Make sure it exists first, and
    # bring it to the current display if it isn't already.
    switch-to = ''
      ${self.maybe-fix-spaces}
      ${self.ensure-displays-have-spaces}
      ${self.force-space-focus} "$1"
    '';

    close-window = ''yabai -m window  --close       '';
    make-main    = ''yabai -m window  --swap   west '';
    toggle-split = ''yabai -m window  --toggle split'';
    next-window  = ''yabai -m window  --focus  next ||
                     yabai -m window  --focus  first'';
    prev-window  = ''yabai -m window  --focus  prev ||
                     yabai -m window  --focus  last '';
    move-next    = ''yabai -m window  --swap   next ||
                     yabai -m window  --swap   first'';
    move-prev    = ''yabai -m window  --swap   prev ||
                     yabai -m window  --swap   last '';
    display-prev = ''yabai -m display --focus  prev ||
                     yabai -m display --focus  last '';
    display-next = ''yabai -m display --focus  next ||
                     yabai -m display --focus  first'';

    current-space = ''
      yabai -m query --spaces |
        jq -r 'map(select(.focused | . == 1)) | .[] | .label'
    '';

    # Tests. These aren't meant to be bound to anything, but are useful to run
    # manually (if you don't mind your spaces getting messed around!)
    run-tests = ''
      CODE=0

      function restore {
        ${debug "Restoring space layout after tests"}
        echo "$ORIGINAL" | ${self.restore-visible-to-displays}
        echo "$ORIGINAL" | ${self.restore-visible-spaces}
        echo "$ORIGINAL" | ${self.restore-focused-space}
      }

      function go {
        ${debug "RUNNING: $1"}
        if "$2"
        then
          ${debug "PASS: $1"}
        else
          CODE=1
          ${error "FAIL: $1"}
        fi
        restore
      }

      ${self.fix-up-spaces}
      ${debug "Storing space layout"}
      ORIGINAL=$(${self.store-currently-visible})

      ${debug "Running tests"}
      ${unlines (map ({name, script}: ''
                       go '${name}' '${makeScript name script}'
                     '')
        (with rec {
          pick-window = makeScript "pick-window" ''
            yabai -m query --windows | jq -r 'map(.id) | .[]' | shuf | head -n1
          '';

          pick-correct-label = makeScript "pick-correct-label" ''
            shuf < ${labelFile} | head -n1
          '';
        };
        # We use this list format, rather than an attrset, to enforce the order.
        # This lets us put simpler tests first.
        [
          {
            name   = "focus-space";
            script = ''
              for N in $(seq 1 10)
              do
                L=$(${self.pick-existing-space})
                ${self.focus-space} "$L"
                ON=$(${self.current-space})
                if [[ "x$ON" = "x$L" ]]
                then
                  ${debug "Focused space $L successfully"}
                else
                  D=$(${self.display-of-space} "$L")
                  D2=$(${self.current-display})
                  ${fatal "Failed to focus space $L ($D); we're on $ON ($D2)"}
                fi
              done
            '';
          }
          {
            name   = "spaces-are-set-up";
            script = ''
              CODE=0
              FOUND=$(yabai -m query --spaces | jq 'length')
              if [[ "$FOUND" -ne ${count} ]]
              then
                ${error "Should have ${count} spaces, actually have $COUNT"}
                CODE=1
              fi

              for L in ${unwords labels}
              do
                FOUND=$(yabai -m query --spaces |
                        jq --arg l "$L" 'map(select(.label == $l)) | length')
                if [[ "$FOUND" -ne 1 ]]
                then
                  ${error "Found $FOUND spaces with label $L"}
                  CODE=1
                fi
              done
              exit $CODE
            '';
          }
          {
            name   = "displays-have-spaces";
            script = ''
              if ! ${self.plugged-in}
              then
                ${info "Only 1 display, skipping test displays-have-spaces"}
                exit 0
              fi

              ${self.ensure-displays-have-spaces}
            '';
          }

      ${self.ensure-displays-have-spaces}
    '';

          {
            name   = "switch-to";
            script = ''
              CODE=0
              START=$(${self.current-space})
              ALL=$(echo -e '${concatStringsSep "\\n" labels}')
              for REPEAT in $(seq 1 10)
              do
                TO=$(echo "$ALL" | shuf | head -n1)
                ${self.switch-to} "$TO"
                ON=$(${self.current-space})
                if ! [[ "x$ON" = "x$TO" ]]
                then
                  ${error "Tried to switch to '$TO', ended up on '$ON'"}
                  CODE=1
                fi
              done
              ${self.switch-to} "$START"
              exit "$CODE"
            '';
          }
        ]))}

      ${debug "Finished tests. Restoring spaces."}
      restore

      if [[ "$CODE" -eq 0 ]]
      then
        ${debug "ALL TESTS PASSED"}
      else
        ${debug "SOME TESTS FAILED"}
      fi
      exit $CODE
    '';
  };

  # Tie the knot, so 'self' works
  commands = makeCommands commands;
};
{
  inherit commands spaces;

  # Make the commands available as a package, so we can invoke them manually
  package = attrsToDirs' "shortcuts" {
    bin = { shortcuts = commands; };
  };
}
