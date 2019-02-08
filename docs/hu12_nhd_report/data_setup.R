library(sf)
library(dplyr)

# symlinked files into project root.

wbd <- read_sf("WBD_National_GDB.gdb", "WBDHU12")
net <- read_sf("NHDPlusV21_National_Seamless.gdb", "NHDFlowline_Network") %>%
  st_zm()

net <- st_transform(net, 5070) %>%
  st_simplify(dTolerance = 30)


wbd <- st_transform(wbd, 5070) %>%
  st_simplify(dTolerance = 30)

net <- net[, 1:40]
net <- select(net, -FDATE, -RESOLUTION, -FLOWDIR, -WBAREACOMI, -Shape_Length, RtnDiv, -VPUIn, -VPUOut)

joiner <- readr::read_csv("map_joiner.csv")

save.image("hu12_nhd_data.Rdata")
