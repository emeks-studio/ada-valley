final: prev: {

  cardano-configs-testnet-preprod = final.stdenv.mkDerivation {
    name = "cardano-configs-testnet-preprod";
    src = ../cardano-configs-testnet-preprod;

    installPhase = ''
      echo "Copying cardano configs for testnet preprod..."
      mkdir -p $out
      cp *.json $out
      chmod 644 $out/*.json
    '';
    };
}