{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
}:
stdenv.mkDerivation rec {
  pname = "viacd";
  name = pname;
  version = "dev";

  src = ./.;

  buildInputs = with pkgs; [
    zig
  ];

  buildPhase = ''
    zig build
  '';

  installPhase = ''
    runHook preInstall
    install -Dvm755 ./zig-out/bin/viacd $out/usr/local/bin/viacd
    runHook postInstall
  '';

  meta = with lib; {
    description = "A lightweight and modern cd-replacement written in zig and inspired by zoxide";
    homepage = "https://github.com/AlphaTechnolog/viacd";
    license = licenses.mit;
    maintainers = [maintainers.AlphaTechnolog];
    platforms = platforms.unix;
  };
}
