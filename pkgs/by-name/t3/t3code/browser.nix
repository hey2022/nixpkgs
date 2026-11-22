{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  patchelfUnstable,
  alsa-lib,
  at-spi2-core,
  dbus,
  expat,
  fontconfig,
  glib,
  libgbm,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  liberation_ttf,
  makeFontsConf,
  nspr,
  nss,
  systemdLibs,
}:

let
  download = {
    x86_64-linux = {
      platform = "linux64";
      sha256 = "deafffa74660b34853a4119c361fd427ac8c9fcb62db51ddb8a797cd83a4ba2d";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      sha256 = "b9b910a57b2a15eb3e55000a2339f93a973934a413ebfc6e585a50ec6c42fd6c";
    };
  };
  archive = download.${stdenv.hostPlatform.system};
  # Headless hosts may have no system fonts, leaving page text invisible.
  fontsConf = makeFontsConf {
    fontDirectories = [ liberation_ttf ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-chrome-headless-shell";
  # Keep these downloads in sync with apps/server/src/preview/PreviewBrowser.ts.
  version = "157.0.8103.38";
  src = fetchurl {
    inherit (archive) sha256;
    url = "https://storage.googleapis.com/chrome-for-testing-public/${finalAttrs.version}/${archive.platform}/chrome-headless-shell-${archive.platform}.zip";
  };

  strictDeps = true;
  nativeBuildInputs = [
    # The upstream binary needs a Nix store ELF interpreter and library paths.
    autoPatchelfHook
    makeWrapper
    patchelfUnstable
    unzip
  ];
  buildInputs = [
    alsa-lib
    at-spi2-core
    dbus
    expat
    glib
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    systemdLibs
  ];
  # Chrome loads Fontconfig dynamically, so autoPatchelf needs it explicitly.
  runtimeDependencies = [ fontconfig.lib ];

  dontBuild = true;
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/chrome-headless-shell"
    # Chrome looks for resource packs and locales relative to its executable.
    cp -R . "$out/libexec/chrome-headless-shell"
    makeWrapper "$out/libexec/chrome-headless-shell/chrome-headless-shell" \
      "$out/bin/chrome-headless-shell" --set-default FONTCONFIG_FILE "${fontsConf}"

    runHook postInstall
  '';

  # Even --version needs the patched interpreter and linked libraries to load.
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/chrome-headless-shell" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Chrome for Testing headless shell for T3 Code";
    homepage = "https://googlechromelabs.github.io/chrome-for-testing/";
    mainProgram = "chrome-headless-shell";
    platforms = builtins.attrNames download;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
