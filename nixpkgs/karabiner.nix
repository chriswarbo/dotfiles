{ lib, shortcuts }:

with builtins;
with lib;
with trace "TODO: Plug scripts in directly, don't add to env"
  trace "TODO: Add tests for scripts" rec {
  # The commands we're going to bind to keys
  inherit (shortcuts) commands package spaces;

  # Add "shift" to the required modifiers of a key_code
  shift = attrs: attrs // {
    modifiers = (attrs.modifiers or {}) // {
      mandatory = (attrs.modifiers.mandatory or []) ++ [ "shift" ];
    };
  };

  # Invoke a command. Uses 'zsh -ic' so ~/.zshrc is sourced (puts Nix in PATH)
  run = cmd: [ { shell_command = "zsh -ic ${cmd}"; } ];

  # Create a key_code with any modifiers allowed
  any = key_code: { inherit key_code; modifiers = { optional = [ "any" ]; }; };

  # Create a Karabiner rule. All rules are "basic", so only the description and
  # "manipulators" (rules) are needed.
  mkRule = description: manipulators: {
    inherit description;
    manipulators = map (m: { type = "basic"; } // m) manipulators;
  };

  # To prevent Space2Control interfering with CapsLock+SpaceBar, we set this
  # variable whenever CapsLock is held down.
  capsLockVar = "caps_lock_held_down";

  # We only want Left Option to control the window manager, not Left Command
  # (even though that is remapped to left_option). To avoid this, we set this
  # variable when Left Command is held, to distinguish it from Left Option.
  leftCommandVar = "left_command_held_down";

  # Set a variable to 1 whilst the given key is held down.
  # Variable setting actions are prepended, since they'll interrupt any prior
  # simulated key presses, which would prevents us simulating a hold
  setVariable = name: entry: entry // {
    to = [ { set_variable = { inherit name; value = 1; }; } ] ++
         (entry.to or []);
    to_after_key_up = [ { set_variable = { inherit name; value = 0; }; } ] ++
                      (entry.to_after_key_up or []);
  };

  # Create a 'condition' that the given variable has the value 0
  whenUnset = name: [ { inherit name; type = "variable_if"; value = 0; } ];

  rules = mapAttrsToList mkRule {
    "Window manager hotkeys" =
      with {
        # Use one 'mod' key to invoke all window manager actions
        mod = key_code: {
          inherit key_code;
          modifiers = {
            mandatory = [ "left_option" ];  # This is our 'mod' key
            optional  = [ "caps_lock"   ];
          };
        };
      };
      # Yabai is controlled by running commands, so every action uses 'run'
      mapAttrsToList (cmd: from:
                       assert hasAttr cmd commands || abort (toJSON {
                         error   = "Shortcut command not found";
                         command = cmd;
                       });
                       {
                         inherit from;
                         # Ignore if left_option has come from Left Command
                         conditions = whenUnset leftCommandVar;
                         to         = run "${package}/bin/shortcuts/${cmd}";
                       }) {
        next-window  =        mod "j"              ;
        prev-window  =        mod "k"              ;
        move-next    = shift (mod "j")             ;
        move-prev    = shift (mod "k")             ;
        display-prev =        mod "left_arrow"     ;
        display-next =        mod "right_arrow"    ;
        toggle-split =        mod "spacebar"       ;
        close-window = shift (mod "c")             ;
        make-main    =        mod "return_or_enter";
        fix-up-emacs =        mod "e"              ;
        force-rejig  =        mod "r"              ;
      }
      ++
      # Switch spaces with number keys
      map (n: with { s = toString n; }; {
            conditions = whenUnset leftCommandVar;
            from       = mod s;
            to         = run "'${commands.switch-to} l${s}'";
          })
          spaces
      ++
      # Send windows to spaces with shift+number keys
      map (n: with { s = toString n; }; {
            conditions = whenUnset leftCommandVar;
            from       = shift (mod s);
            to         = run "'yabai -m window --space l${s}''";
          })
          spaces
      ;

    "CapsLock as Control" = [
      # Set a variable so we can special-case CapsLock+SpaceBar for Emacs
      (setVariable capsLockVar {
        from        = any "caps_lock";
        to          = [ { key_code = "left_control"; } ];
      })
    ];

    "Space2Control (unless CapsLock is held)" = [
      {
        description = "Make spacebar act as Control when held";
        conditions  = whenUnset capsLockVar;
        from        = any "spacebar";
        to          = [ { key_code = "left_control"; } ];
        to_if_alone = [ { key_code = "spacebar";     } ];
      }
    ];

    "Use § for Esc on touchbar keyboard; to get § use Fn+§" =
      with {
        haveTouchBar = [ {
          identifiers = [ { is_keyboard = true; vendor_id = 1452; } ];
          type        = "device_if";
        } ];
      };
      [
      {
        conditions = haveTouchBar;
        from       = {
          key_code  = "non_us_backslash";
          modifiers = { optional = [ "caps_lock" ]; };
        };
        to = [ { key_code = "escape"; } ];
      }
      {
        conditions = haveTouchBar;
        from       = {
          key_code  = "non_us_backslash";
          modifiers = { mandatory = [ "fn" ]; };
        };
        to = [ { key_code = "non_us_backslash"; } ];
      }
    ];

    "Switch around modifiers" = [
      # Make modifiers more like PS/2 keyboard

      # Also set leftCommandVar so we can distinguish from the real Left Option
      (setVariable leftCommandVar {
        from = any "left_command";
        to   = [ { key_code = "left_option"; } ];
      })
      {
        from = any "left_control";
        to   = [ { key_code = "left_command"; } ];
      }
      # Make alternative SpaceBar when we want to hold it
      {
        from = any "right_command";
        to   = [ { key_code = "spacebar"; } ];
      }
    ];
  };
};
# Pad the rules with all the other metadata karabiner.json expects
{
  global = {
    check_for_updates_on_startup  = true;
    show_in_menu_bar              = true;
    show_profile_name_in_menu_bar = false;
  };
  profiles = [ {
    complex_modifications = {
      name                 = "Default profile";
      rules                = rules;  # This is the main part of the config
      devices              = [];
      fn_function_keys     = [];
      selected             = true;
      simple_modifications = [];
      virtual_hid_keyboard = { country_code = 0; mouse_key_xy_scale = 100; };
      parameters           = {
        "basic.simultaneous_threshold_milliseconds"    = 50;
        "basic.to_delayed_action_delay_milliseconds"   = 500;
        "basic.to_if_alone_timeout_milliseconds"       = 1000;
        "basic.to_if_held_down_threshold_milliseconds" = 500;
        "delay_milliseconds_before_open_device"        = 1000;
        "mouse_motion_to_scroll.speed"                 = 100;
      };
    };
  } ];
}