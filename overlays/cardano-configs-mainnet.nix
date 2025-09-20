final: prev: {

  cardano-configs-mainnet = final.stdenv.mkDerivation {
    name = "cardano-configs-mainnet";
    src = ../cardano-configs-mainnet;

    installPhase = ''
      echo "Copying cardano configs for mainnet..."
      mkdir -p $out
      cp *.json $out
      chmod 644 $out/*.json
    '';
    };
}