{ attrsToDirs', git, silver-searcher, wrap }:

attrsToDirs' "artemis-tools" {
  bin = {
    artemis = wrap {
      name  = "artemis";
      file  = ./artemis.sh;
      paths = [ git ];
    };
    tasks = wrap {
      name  = "tasks";
      file  = ./tasks.sh;
      paths = [ silver-searcher ];
    };
  };
}
