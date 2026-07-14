# AMRAgent R Dependency Installer
print("Installing required R packages for Vivli/ATLAS AMR EDA...")

required_packages <- c("tidyverse", "janitor", "readr", "scales", "png", "gridExtra", "AMR", "arrow")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if (length(new_packages)) {
  install.packages(new_packages, repos = "https://cloud.r-project.org/")
  print("All missing packages installed successfully!")
} else {
  print("All packages are already installed.")
}
