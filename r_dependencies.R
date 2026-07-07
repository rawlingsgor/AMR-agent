# AMRAgent R Dependency Installer
print("Installing required R packages for Stage 1 Data Engineering...")

required_packages <- c("tidyverse", "AMR", "arrow")

new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(new_packages)) {
  install.packages(new_packages, repos='https://cloud.r-project.org/')
  print("All packages installed successfully!")
} else {
  print("All packages are already installed.")
}
