{
  stdenvNoCC,
  lib,
  fetchurl,
  autoPatchelfHook,
  php,
  writeShellApplication,
  curl,
  gnugrep,
  common-updater-scripts,
}:

let
  soFile =
    {
      "8.0" = "tideways-php-8.0.so";
      "8.1" = "tideways-php-8.1.so";
      "8.2" = "tideways-php-8.2.so";
      "8.3" = "tideways-php-8.3.so";
    }
    .${lib.versions.majorMinor php.version} or (throw "Unsupported PHP version.");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tideways-php";
  extensionName = "tideways";
  version = "5.19.0";

  src =
    finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported platform for tideways-php: ${stdenvNoCC.hostPlatform.system}");

  nativeBuildInputs = lib.optionals stdenvNoCC.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall
    install -D ${soFile} $out/lib/php/extensions/tideways.so
    runHook postInstall
  '';

  passthru = {
    sources = {
      "x86_64-linux" = fetchurl {
        url = "https://s3-eu-west-1.amazonaws.com/tideways/extension/${finalAttrs.version}/tideways-php-${finalAttrs.version}-x86_64.tar.gz";
        hash = "sha256-AaTrbrdi/XLeKlG+//DTjRGQEheLTtfHwx7Ztn+/Nuk=";
      };
      "aarch64-linux" = fetchurl {
        url = "https://s3-eu-west-1.amazonaws.com/tideways/extension/${finalAttrs.version}/tideways-php-${finalAttrs.version}-arm64.tar.gz";
        hash = "sha256-BSXKLxh2ex7rU4vsxHWqQIca+yFQlZDbB0TyNcpYmKs=";
      };
      "aarch64-darwin" = fetchurl {
        url = "https://s3-eu-west-1.amazonaws.com/tideways/extension/${finalAttrs.version}/tideways-php-${finalAttrs.version}-macos-arm.tar.gz";
        hash = "sha256-a63cr/547MxyB7irVlONUpdep3M42YA2C6H9sGbEAI8=";
      };
    };

    updateScript = "${
      writeShellApplication {
        name = "update-tideways-probe";
        runtimeInputs = [
          curl
          gnugrep
          common-updater-scripts
        ];
        text = ''
          NEW_VERSION=$(curl --fail -L https://tideways.com/profiler/downloads | grep -E 'https://tideways.s3.amazonaws.com/extension/[0-9]+\.[0-9]+\.[0-9]+/tideways-php-[0-9]+\.[0-9]+\.[0-9]+-x86_64.tar.gz' | grep -oP 'extension/\K[0-9]+\.[0-9]+\.[0-9]+')

          if [[ "${finalAttrs.version}" = "$NEW_VERSION" ]]; then
              echo "The new version same as the old version."
              exit 0
          fi

          for platform in ${lib.escapeShellArgs finalAttrs.meta.platforms}; do
            update-source-version "php82Extensions.tideways" "$NEW_VERSION" --ignore-same-version --source-key="sources.$platform"
          done
        '';
      }
    }/bin/update-tideways-probe";
  };

  meta = with lib; {
    description = "Tideways PHP Probe";
    homepage = "https://tideways.com/";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    maintainers = with maintainers; [ shyim ];
    platforms = lib.attrNames finalAttrs.passthru.sources;
  };
})
