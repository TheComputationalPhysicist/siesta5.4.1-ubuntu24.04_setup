#!/usr/bin/env bash
#
# install_siesta_5_4_1_ubuntu24.sh
# One-script installer for SIESTA 5.4.1 on Ubuntu 24
# Installs system deps (only missing), builds xmlf90 (patched), builds SIESTA into ~/Code/siesta-5.4.1
#
# Defaults: MAKEJ=2 (safe for i5 3rd gen / 16 GB). Change MAKEJ near top if you want 4.
#sudo apt update
#sudo apt install -y dos2unix    # only if dos2unix not installed
#dos2unix install.sh
#chmod +x install.sh
#./install.sh
set -euo pipefail
IFS=$'\n\t'

# ===== Config =====
SIESTA_VER="5.4.1"
INSTALLDIR="${HOME}/Code/siesta-${SIESTA_VER}"
DEPSDIR="${INSTALLDIR}/deps"
XMLDIR="${DEPSDIR}/xmlf90"
MAKEJ=2      # change to 4 if you prefer (but 2 is safe)
LOGDIR="${HOME}"
CMAKE_MIN_VER="3.20"
# ==================

echo "================================================================"
echo " SIESTA ${SIESTA_VER} installer for Ubuntu 24"
echo " Install dir : ${INSTALLDIR}"
echo " xmlf90 dir  : ${XMLDIR}"
echo " Parallelism : ${MAKEJ}"
echo " Logs        : ${LOGDIR} (look for xmlf90_*.log and siesta_*.log)"
echo "================================================================"
sleep 1

# Helper: check package installed
_has_pkg() {
  dpkg -s "$1" &>/dev/null
}

# 1) Ensure apt packages installed (only missing ones)
REQUIRED_PKGS=(
  build-essential gfortran gcc g++ make cmake pkg-config
  git wget curl
  autoconf automake libtool m4
  openmpi-bin libopenmpi-dev
  libnetcdf-dev libnetcdff-dev
  libxc-dev
  libopenblas-dev liblapack-dev libblas-dev
  libscalapack-openmpi-dev
  libfftw3-dev
  libreadline-dev
  python3 python3-pip
  libxml2-dev
)

MISSING=()
echo "==> Checking system packages..."
for p in "${REQUIRED_PKGS[@]}"; do
  if _has_pkg "$p"; then
    printf "  ✔ %s\n" "$p"
  else
    printf "  ✘ %s\n" "$p"
    MISSING+=("$p")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo
  echo "==> Installing missing packages (sudo required): ${MISSING[*]}"
  sudo apt update
  sudo apt install -y "${MISSING[@]}"
else
  echo "==> All required apt packages already installed."
fi

# Check cmake version
if command -v cmake >/dev/null 2>&1; then
  CMVER=$(cmake --version | head -n1 | awk '{print $3}')
  echo "==> CMake version: $CMVER"
  if ! dpkg --compare-versions "$CMVER" ge "$CMAKE_MIN_VER"; then
    echo "  CMake version < ${CMAKE_MIN_VER}. Installing latest cmake from apt (may upgrade)."
    sudo apt update
    sudo apt install -y cmake
  fi
fi

# 2) Prepare directories
echo "==> Creating install and deps directories..."
mkdir -p "${INSTALLDIR}"
mkdir -p "${DEPSDIR}"
mkdir -p "${INSTALLDIR}/build_logs"

# 3) Download and extract SIESTA source (visible)
echo "==> Downloading SIESTA ${SIESTA_VER} source into ${INSTALLDIR}..."
cd "${INSTALLDIR}"
if [ -f "siesta-${SIESTA_VER}.tar.gz" ]; then
  echo "  - SIESTA tarball already present"
else
  wget -c "https://gitlab.com/siesta-project/siesta/-/archive/${SIESTA_VER}/siesta-${SIESTA_VER}.tar.gz" -O "siesta-${SIESTA_VER}.tar.gz"
fi

echo "==> Extracting SIESTA source (visible) ..."
tar -xzf "siesta-${SIESTA_VER}.tar.gz" --strip-components=1

# 4) Clone/build xmlf90 (patch Makefile.am for /lib.mk issue)
echo "==> Preparing xmlf90 (source in ~/xmlf90-src) ..."
if [ -d "${HOME}/xmlf90-src" ]; then
  echo "  - reusing existing ~/xmlf90-src"
  cd "${HOME}/xmlf90-src"
  git fetch --all --tags || true
else
  cd "${HOME}"
  git clone https://gitlab.com/siesta-project/libraries/xmlf90.git xmlf90-src
  cd xmlf90-src
fi

# checkout stable tag (1.5.4)
git checkout 1.5.4 || git checkout tags/1.5.4 || true
echo "  - xmlf90 at: $(git describe --tags --always)"

# Patch known /lib.mk problem inside src/wxml/Makefile.am if present
WXML_MAKE_AM="src/wxml/Makefile.am"
if [ -f "${WXML_MAKE_AM}" ]; then
  if grep -q "/lib.mk" "${WXML_MAKE_AM}"; then
    echo "==> Patching ${WXML_MAKE_AM} to replace '/lib.mk' with \$(top_srcdir)/lib.mk"
    cp "${WXML_MAKE_AM}" "${WXML_MAKE_AM}.bak"
    sed -i 's|/lib.mk|$(top_srcdir)/lib.mk|g' "${WXML_MAKE_AM}"
    echo "  - backup: ${WXML_MAKE_AM}.bak"
  else
    echo "==> No /lib.mk entry in ${WXML_MAKE_AM}; no patch needed."
  fi
else
  echo "==> ${WXML_MAKE_AM} not found; continuing."
fi

# regenerate autotools & configure xmlf90 with prefix XMLDIR
echo "==> Running autoreconf (xmlf90)... (logs -> ${LOGDIR}/xmlf90_autoreconf.log)"
autoreconf -fvi 2>&1 | tee "${LOGDIR}/xmlf90_autoreconf.log" || true

echo "==> Configuring xmlf90 with prefix=${XMLDIR} (logs -> ${LOGDIR}/xmlf90_configure.log)"
./configure --prefix="${XMLDIR}" FC=gfortran 2>&1 | tee "${LOGDIR}/xmlf90_configure.log"

echo "==> Building xmlf90 (make -j${MAKEJ}) (logs -> ${LOGDIR}/xmlf90_make.log)"
make -j"${MAKEJ}" 2>&1 | tee "${LOGDIR}/xmlf90_make.log" || true

echo "==> Installing xmlf90 into prefix=${XMLDIR} (logs -> ${LOGDIR}/xmlf90_install.log)"
# Most autotools respect --prefix via 'make install'; use prefix param to be sure
make install prefix="${XMLDIR}" 2>&1 | tee "${LOGDIR}/xmlf90_install.log" || true

# Verify xmlf90 artifacts
echo "==> xmlf90 install contents (include/lib):"
ls -l "${XMLDIR}/include" 2>/dev/null || true
ls -l "${XMLDIR}/lib" 2>/dev/null || true

# 5) Configure SIESTA with CMake (point to local xmlf90)
echo "==> Configuring SIESTA (CMake). Logs -> ${LOGDIR}/siesta_cmake_log.txt"
cd "${INSTALLDIR}"
rm -rf build
mkdir -p build
cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX="${INSTALLDIR}" \
  -DCMAKE_C_COMPILER="$(which mpicc)" \
  -DCMAKE_Fortran_COMPILER="$(which mpif90)" \
  -DXMLF90_ROOT="${XMLDIR}" \
  -DXMLF90_INCLUDE_DIR="${XMLDIR}/include" \
  -DXMLF90_LIBRARY="${XMLDIR}/lib/libxmlf90.a" \
  -DDSIESTA_WITH_MPI=ON \
  -DDSIESTA_WITH_NETCDF=ON \
  -DDSIESTA_WITH_LIBXC=ON \
  -DDSIESTA_WITH_SCALAPACK=ON \
  -DCMAKE_BUILD_TYPE=Release 2>&1 | tee "${LOGDIR}/siesta_cmake_log.txt" || true

echo "---- CMake tail ----"
tail -n 60 "${LOGDIR}/siesta_cmake_log.txt" || true

# 6) Build SIESTA
echo "==> Building SIESTA (make -j${MAKEJ}). Logs -> ${LOGDIR}/siesta_make.log"
make -j"${MAKEJ}" 2>&1 | tee "${LOGDIR}/siesta_make.log" || true

echo "---- build tail ----"
tail -n 140 "${LOGDIR}/siesta_make.log" || true

# 7) Install (CMake install target) and verify binary
echo "==> Installing SIESTA into ${INSTALLDIR} (no sudo). Logs -> ${LOGDIR}/siesta_install.log"
cmake --build . --target install 2>&1 | tee "${LOGDIR}/siesta_install.log" || true

echo "==> Post-install: list bin/"
ls -l "${INSTALLDIR}/bin" || true

# 8) Add to PATH in .bashrc (if not already)
BASHRC="${HOME}/.bashrc"
ADDLINE="export PATH=\"${INSTALLDIR}/bin:\$PATH\""
if grep -Fxq "${ADDLINE}" "${BASHRC}" ; then
  echo "==> PATH already contains SIESTA bin (in ~/.bashrc)."
else
  echo "${ADDLINE}" >> "${BASHRC}"
  echo "==> Added SIESTA bin to PATH in ~/.bashrc (reload or open new shell to take effect)."
fi

echo
echo "================================================================"
echo " Installation complete (check logs if anything failed):"
echo "  - CMake log : ${LOGDIR}/siesta_cmake_log.txt"
echo "  - Make log  : ${LOGDIR}/siesta_make.log"
echo "  - xmlf90 logs: ${LOGDIR}/xmlf90_*.log"
echo
echo " To use SIESTA in the current shell run:"
echo "   export PATH=\"${INSTALLDIR}/bin:\$PATH\""
echo " Then test with:"
echo "   siesta --version"
echo " or (MPI):"
echo "   mpirun -np 2 siesta --version"
echo
echo " If anything failed, paste the last 200 lines from ${LOGDIR}/siesta_make.log and the last 80 lines from ${LOGDIR}/siesta_cmake_log.txt here and I will debug."
echo "================================================================"
