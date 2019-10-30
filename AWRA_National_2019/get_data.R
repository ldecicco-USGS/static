library(drake)
# https://mikejohnson51.github.io/AOI/

plan <- drake_plan(
  start_location = AOI::geocode(location = "Great Salt Lake", pt = TRUE),
  start_nhdplusid = nhdplusTools::discover_nhdplus_id(start_location$pt$geometry),
  nldi_feature = list(featureSource = "comid", 
                      featureID = start_nhdplusid),
  nldi_sources = nhdplusTools::discover_nldi_sources(),
  nldi_navigation = nhdplusTools::discover_nldi_navigation(nldi_feature),
  UT = nhdplusTools::navigate_nldi(nldi_feature = nldi_feature, 
                                   mode = "upstreamTributaries", 
                                   data_source = ""),
  nwissite = nhdplusTools::navigate_nldi(nldi_feature = nldi_feature, 
                                         mode = "upstreamTributaries", 
                                         data_source = "nwissite"),
  nhdp = nhdplusTools::subset_nhdplus(UT$nhdplus_comid, 
                                      output_file = "data/nhdp_subset.gpkg", 
                                      nhdplus_data = "download", 
                                      status = TRUE, 
                                      overwrite = TRUE)
)

make(plan)