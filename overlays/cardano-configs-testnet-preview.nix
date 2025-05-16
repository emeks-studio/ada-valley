final: prev: {

  cardano-configs-testnet-preview = final.stdenv.mkDerivation {
    name = "cardano-configs-testnet-preview";
    src = ../cardano-configs-testnet-preview; 

    installPhase = ''
      echo "Installing another custom app..."
      mkdir -p $out
      cp *.json $out
      chmod 644 $out/*.json
    '';
    };
}