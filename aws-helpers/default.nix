{ awscli, bash, buildEnv, jq, lib, mkBin }:

rec {
  api-info = mkBin {
    name  = "api-info";
    paths = [ bash awscli jq ];
    file  = ./api-info.sh;
  };

  healthcheck = mkBin {
    name  = "healthcheck";
    paths = [ api-info bash awscli jq ];
    file  = ./healthcheck.sh;
  };

  login = mkBin {
    name  = "aws-login";
    paths = [ bash awscli ];
    file  = ./login.sh;
  };

  run-healthcheck = mkBin {
    name  = "run-healthcheck";
    paths = [ bash awscli jq ];
    file  = ./run-healthcheck.sh;
  };

  combined = buildEnv {
    name  = "aws-helpers";
    paths = [ api-info healthcheck login ];
  };
}
