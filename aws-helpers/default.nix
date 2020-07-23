{ awscli, bash, buildEnv, jq, lib, mkBin }:

rec {
  api-info = mkBin rec {
    name  = "api-info";
    paths = [ bash awscli jq ];
    file  = ./api-info.sh;
  };

  healthcheck = mkBin rec {
    name  = "healthcheck";
    paths = [ api-info bash awscli jq ];
    file  = ./healthcheck.sh;
  };

  login = mkBin rec {
    name  = "aws-login";
    paths = [ bash awscli ];
    file  = ./login.sh;
  };

  combined = buildEnv {
    name  = "aws-helpers";
    paths = [ api-info healthcheck login ];
  };
}
