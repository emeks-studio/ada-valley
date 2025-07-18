final: prev: {

  cardano-configs-testnet-preview = final.stdenv.mkDerivation {
    name = "cardano-configs-testnet-preview";
    src = ../cardano-configs-testnet-preview; 

    installPhase = ''
      echo "Copying cardano configs for testnet preview..."
      mkdir -p $out
      cp *.json $out
      chmod 644 $out/*.json
    '';
    };
}