##Example
````nix
{
  description = "A custom JDK with an additional trust in CACERTS";

  inputs = {
    # As of the day of making this sample, Graalvm-ce-musl in failing in nixpkgs/unstable
    nixpkgs.url = "github:NixOS/nixpkgs/6774f7bc253789b113a4f39285dc0fa100abeacc";

    nix-utils-java = {
        url = "github:pchesneau/Nix-Utils?dir=java";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-utils-java }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          certA = ./your_custom_cert.pem;

        in
        {
          myCustomJdk = nix-utils-java.lib.mkCustomJdk {
            inherit pkgs;
            jdk = pkgs.graalvmPackages.graalvm-ce-musl; # The JDK you want to customize
            extraCerts = [ certA  ];
          };
          default = self.packages.${system}.myCustomJdk;
        }
      );
    };
}
````