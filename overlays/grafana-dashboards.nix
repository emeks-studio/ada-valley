final: prev: {

  grafana-dashboards = final.stdenv.mkDerivation {
    name = "grafana-dashboards";
    src = ../dashboards/grafana;

    installPhase = ''
      echo "Copying All Grafana dashboards..."
      mkdir -p $out
      cp *.json $out
      chmod 644 $out/*.json
    '';
    };
}