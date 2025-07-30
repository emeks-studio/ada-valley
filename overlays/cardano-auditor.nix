final: prev: {

  cardano-auditor = with final; stdenv.mkDerivation {
    name = "cardano-auditor";
    src = ../cardano-auditor;

    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [bash coreutils gnugrep jq];

    installPhase = ''
      echo "Copying Cardano Auditor script..."
      mkdir -p $out/bin
      cp audit-cardano-node.sh $out/bin/cardano-auditor
      chmod +x $out/bin/cardano-auditor
      wrapProgram $out/bin/cardano-auditor \
        --prefix PATH : ${lib.makeBinPath [jq coreutils ]}
    '';
    };
}