{ awscli, bash, buildEnv, jq, lib, mkBin }:

rec {
  login = mkBin rec {
    name  = "aws-login";
    paths = [ bash awscli ];
    file  = ./login.sh;
  };

  api-info = mkBin rec {
    name  = "api-info";
    paths = [ bash awscli jq ];
    file  = ./api-info.sh;
  };

  combined = buildEnv {
    name  = "aws-helpers";
    paths = [ api-info login ];
  };
}
