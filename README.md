SIESTA 5.4.1 Installation on Ubuntu 24.04 (No Conda)

This repository contains a single fully automated Bash script that installs SIESTA 5.4.1 natively on Ubuntu 24.04 (no Conda environment used).
This makes the setup cleaner, faster, and more stable compared to Conda-based videos found on YouTube.

🚀 Features
Builds SIESTA 5.4.1 from source
Compiles xmlf90 (patched automatically)

Enables:
MPI parallel execution
NetCDF support
LibXC support
Scalapack
BLAS/LAPACK / OpenBLAS

Installs everything into:
~/Code/siesta-5.4.1

Automatically adds SIESTA to your PATH
Includes build logs for debugging

📁 Repository Contents
install_siesta_5_4_1_ubuntu24.sh → One-script installer
Logs will be generated in your home directory

🛠️ How to Use
sudo apt update
sudo apt install -y dos2unix    # only if dos2unix not installed
dos2unix install.sh
chmod +x install.sh
./install_siesta_5_4_1_ubuntu24.sh

📝 Requirements
Ubuntu 24.04
Internet connection
Min 2 CPU cores (recommended 4)
~2 GB free space

⭐ Why This Script is Better?
✔ No Conda environment
✔ No manual dependency installation
✔ Auto-patching of xmlf90
✔ Clean SIESTA installation in local directory
✔ Beginner-friendly + research-ready
✔ Tested on Ubuntu 24.04 LTS

🎥 Related YouTube Videos

SIESTA Installation (Parallel)
https://youtu.be/Zq3Y4RjPqp8

Band Structure + DOS/PDOS Plotting
https://youtu.be/gghbO03kWCQ

Automated Fatband Generation
https://youtu.be/_WJ6VO6Ozyo

ASE Installation
https://youtu.be/HhMvCK2xWys

📧 Contact
Dr. Himalay Kolavada
Assistant Professor, Department of Physics
Gokul Science College, Gokul Global University
📩 himalaykolavada642@gmail.com
