{ androidenv, cacert, mkBin, python3, run }:

{
  androidApp = args: mkBin {
    inherit (args) name;
    file = androidenv.emulateApp ({
      abiVersion      = "x86";
      platformVersion = "28";
      sdkExtraArgs    = args.sdkExtraArgs or {};
    } // args) + "/bin/run-test-emulator";
  };

  apkpure = { name, path, sha256 }: run {
    name      = name + ".apk";
    drvExtras = {
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash     = sha256;
    };
    paths  = [ (python3.withPackages (p: [ p.beautifulsoup4 ])) ];
    vars   = { url = "https://apkpure.com/${path}/download?from=details"; };
    script = ''
      #!/usr/bin/env python3
      from bs4            import BeautifulSoup
      from gzip           import GzipFile
      from json           import loads
      from os             import getenv
      from urllib.request import Request, urlopen, urlretrieve
      headers = {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:78.0) ' +
          'Gecko/20100101 Firefox/78.0',
        'Accept': ','.join(["text/html", "application/xhtml+xml",
          "application/xml;q=0.9", "image/webp", "*/*;q=0.8"]),
        'Accept-Language': "en-GB,en;q=0.5",
        'Accept-Encoding': "gzip, deflate",
        'Connection': "keep-alive",
        'Upgrade-Insecure-Requests': "1"
      }
      sslcert = "${cacert}/etc/ssl/certs/ca-bundle.crt"
      output  = getenv('out')

      get = lambda url: urlopen(
        Request(url, data=None, headers=headers),
        cafile=sslcert
      )

      page  = GzipFile(fileobj=get(getenv('url')))
      soup  = BeautifulSoup(page.read(), "html.parser")
      links = [a['href'] for p in soup.find_all("p", class_="down-click") \
                         for a in p.find_all("a")]

      assert len(links) == 1 and links[0] != None, repr({
        'error': 'Should have one link',
        'links': links,
        'soup' : soup
      })
      print(repr({'links': links}))

      with get(links[0]) as f:
        with open(output, 'bw') as out:
          out.write(f.read())
    '';
  };
}
