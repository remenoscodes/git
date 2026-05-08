{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    gnumake
    openssl
    zlib
    curl
    expat
  ];
}
