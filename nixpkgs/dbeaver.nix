{ dbeaver, getNixpkgs, jdk11 }:

with rec {
  inherit (builtins) elem trace;

  # Needs a newer nixpkgs than the time of writing, for Darwin support
  # TODO: Test whether this is still needed, so we know when
  newSrc = getNixpkgs {
    rev    = "a94edb03b1b04a875710c29d9b19dae7cc8c7425";
    sha256 = "0f6l8j2ziwfc3k7qvw49clb8bajp6mkdvp0vzbjzcgxkqdsyvrn0";
  };

  newPkgs = import newSrc {};

  warnUnlessNeeded =
    if elem "x86_64-darwin" dbeaver.meta.platforms
       then trace ''
         WARNING: DBeaver seems to be supported on Darwin upstream, so our
         override may not be needed anymore.
       ''
       else (x: x);

  overridden = (newPkgs.dbeaver.override (old: {
    # Avoid 'md5WithRSAEncryption_oid cannot be resolved or is not a field'
    jdk = jdk11;
  })).overrideAttrs (old: rec {
    # References broken fetchedMavenDeps
    buildPhase = ''
      mvn package --offline \
                  -Dmaven.repo.local=$(cp -dpR ${fetchedMavenDeps}/.m2 ./ &&
                                       chmod +w -R .m2 &&
                                        pwd)/.m2
    '';

    # Wrong sha256 hash
    fetchedMavenDeps = old.fetchedMavenDeps.overrideAttrs (old: {
      outputHash = "sha256-JTdKHeiyRMK6liVSwEqttJUcbt9hcVC5FMiyN4fUwrw=";
    });
  });
};

warnUnlessNeeded overridden
