{ awscli, bash, buildEnv, jq, lib, mkBin, python3 }:

rec {
  api-info = mkBin {
    name  = "api-info";
    paths = [ bash awscli jq ];
    file  = ./api-info.sh;
  };

  healthcheck = mkBin {
    name  = "healthcheck";
    paths = [ api-info awscli bash jq run-healthcheck ];
    file  = ./healthcheck.sh;
  };

  kinesis-consumer = mkBin {
    name  = "kinesis-consumer";
    paths = [ (python3.withPackages (p: [
      p.boto3
      p.pygments
      (p.buildPythonPackage rec {
        pname   = "kinesis";
        version = "0.0.1a13";
        src     = p.fetchPypi {
          inherit pname version;
          sha256 = "1mnhardvn6zp7gdfr04x70fqs0q5nr04rrd6z35vdsa4hd804vki";
        };
        buildInputs = [ (python3.withPackages (p: [
          p.boto3
          p.pygments
        ])) ];
      })
    ])) ];
    file  = ./kinesis-consumer.py;
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
    paths = [ api-info healthcheck login kinesis-consumer ];
  };
}
