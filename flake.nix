{
  description = "A self-hostable pastebin for your tailnet";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ] (system:
      let
        version = builtins.substring 0 8 self.lastModifiedDate;
        pkgs = import nixpkgs { inherit system; };
      in {
        packages = rec {
          tclipd = pkgs.buildGo122Module {
            pname = "tclipd";
            version = "0.1.0-${version}";
            go = pkgs.go;
            src = ./.;
            subPackages = "cmd/tclipd";
            vendorHash = "sha256-nxKlKxpr7PZhDLk/J3TBjdhLjy7EYqmMGF+y4hgRgRQ=";
          };

          tclip = pkgs.buildGo122Module {
            pname = "tclip";
            inherit (tclipd) src version vendorHash;
            subPackages = "cmd/tclip";
            go = pkgs.go;

            CGO_ENABLED = "0";
          };

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/gmemstr/tclip";
            tag = "latest";
            config.Cmd = [ "${tclipd}/bin/tclipd" ];
            contents = [ pkgs.cacert ];
          };

          portable-service = let
            web-service = pkgs.substituteAll {
              name = "tclip.service";
              src = ./run/portable-service/tclip.service.in;
              inherit tclipd;
            };
          in pkgs.portableService {
            inherit (tclipd) version;
            pname = "tclip";
            description = "The tclip service";
            homepage = "https://github.com/tailscale-dev/tclip";
            units = [ web-service ];
            symlinks = [{
              object = "${pkgs.cacert}/etc/ssl";
              symlink = "/etc/ssl";
            }];
          };

          default = docker;
        };

        apps.default =
          utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
            go-tools
            sqlite-interactive

            yarn
            nodejs
          ];

          TSNET_HOSTNAME = "paste-devel";
        };
      }) // {};
}
