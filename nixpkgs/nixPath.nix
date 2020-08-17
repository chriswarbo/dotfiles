# These entries can be used as <foo> or <foo/bar.txt> within Nix. We should
# always try to use paths like these in Nix rather than strings, since Nix
# will check whether paths we refer to actually exist. For example if we use
# the path <home/.ssh/config> then Nix will abort evaluation if it doesn't
# exist; this is usually preferable to using strings like
# (<home> + "/.ssh/config") which will be evaluated without error, only to
# cause "file not found" problems later on (in a builder if we're lucky; if
# we're not it could get written to scripts or config files which we only
# notice when running them at some arbitrary point in the future!)

# NOTE: Paths are used in two different ways, depending on the behaviour we
# want:
#  - Sometimes we want to take a snapshot of the files we reference. For
#    example, we might use libraries like <nix-helpers> or read options from
#    <home/.config/foo>. If these paths get hard-coded into our builders,
#    binaries, etc. then the .drv files will give different results whenever
#    we update/alter those configs. For example, if a working package gets
#    garbage collected, we might never be able to rebuild it again; even if
#    we still have the .drv file!
#    To avoid this we should add a snapshot of these paths to the Nix store,
#    so that everything we reference is immutable. This is what Nix will do
#    by default if we use a path as a string, e.g.
#        "ls ${<nix-helpers>}"
#        builtins.toJSON [ <nix-helpers> ]
#        runCommand "foo" { helpers = <nix-helpers>; } "bar"
#    Be careful that your snapshots aren't too big! For example, don't keep
#    adding snapshots of your entire home directory just to reference a
#    single file!
#  - Other times we want a path to appear literally, e.g. if we're writing a
#    downloader's config we want it to save things into <home/Downloads>,
#    not into some snapshot of that directory (also, we can't save into an
#    immutable filesystem!). In these cases we should send the path through
#    the 'builtins.toString' function, e.g.
#        { destination = builtins.toString <home/Downloads>; }

# NOTE: Relying on these paths causes a bootstrapping problem: our config
# depends on these paths, but these paths are made available by our config.
# If we try to activate this config using 'darwin-rebuild switch' we'll get an
# error ("file foo was not found in the Nix search path"). To break this cycle
# we need to add these to the NIX_PATH explicitly the first time. We can do
# this manually, e.g.
#     NIX_PATH="$NIX_PATH:home=$HOME:..." darwin-rebuild switch
# We also provide a 'switch.sh' script to do this for us, which uses the
# following definitions directly (which is why this file works standalone!)
with rec {
  sources = import ./nix/sources.nix;
  nixpkgs = import sources.nixpkgs.outPath { config = {}; overlays = []; };
};
rec {
  # This [ "foo=bar" ] form is useful for nix.nixPath in a NixOS/Darwin config
  list = nixpkgs.lib.mapAttrsToList (name: path: "${name}=${path}") {
    darwin = sources.nix-darwin.outPath;
    darwin-config = builtins.toString ./darwin-configuration.nix;
    dotfiles = builtins.fetchGit ./..;
    home = builtins.getEnv "HOME";
    nix-config = sources.nix-config.outPath;
    nix-helpers = sources.nix-helpers.outPath;
    nixpkgs = sources.nixpkgs.outPath;
    warbo-packages = sources.warbo-packages.outPath;
  };

  # This "foo=bar:baz=quux" form is useful for NIX_PATH environment variables
  string = builtins.concatStringsSep ":" list;
}
