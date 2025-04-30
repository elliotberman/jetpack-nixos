{ cmake
, cudaPackages
, debs
, dpkg
, opencv
, stdenv
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    vpi3
    ;
in
stdenv.mkDerivation {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "vpi3-samples";
  inherit (debs.common.vpi3-samples) src version;

  unpackCmd = "dpkg -x $src source";
  sourceRoot = "source/opt/nvidia/vpi3/samples";

  nativeBuildInputs = [ cmake cuda_nvcc dpkg ];
  buildInputs = [ cuda_cudart opencv vpi3 ];

  configurePhase = ''
    runHook preBuild

    for dirname in $(find . -type d | sort); do
      if [[ -e "$dirname/CMakeLists.txt" ]]; then
        echo "Configuring $dirname"
        pushd $dirname
        cmake .
        popd 2>/dev/null
      fi
    done

    runHook postBuild
  '';

  buildPhase = ''
    runHook preBuild

    for dirname in $(find . -type d | sort); do
      if [[ -e "$dirname/CMakeLists.txt" ]]; then
        echo "Building $dirname"
        pushd $dirname
        make $buildFlags
        popd 2>/dev/null
      fi
    done

    runHook postBuild
  '';

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall

    install -Dm 755 -t $out/bin $(find . -type f -maxdepth 2 -perm 755)

    runHook postInstall
  '';
}
