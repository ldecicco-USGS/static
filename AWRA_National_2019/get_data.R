library(drake)
library(dplyr)
# https://mikejohnson51.github.io/AOI/

set_precision <- function(x, prec) {
  st_precision(x) = prec
  x
}

sp_bbox <- function(g) {
  matrix(as.numeric(st_bbox(g)), 
         nrow = 2, dimnames = list(c("x", "y"), 
                                   c("min", "max")))
}

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
  wqpsite = nhdplusTools::navigate_nldi(nldi_feature = nldi_feature, 
                                         mode = "upstreamTributaries", 
                                         data_source = "wqp"),
  nhdp = nhdplusTools::subset_nhdplus(UT$nhdplus_comid, 
                                      output_file = file_out("data/nhdp_subset.gpkg"), 
                                      nhdplus_data = "download", 
                                      status = TRUE, 
                                      overwrite = TRUE),
  nhd_basin = nhdplusTools::get_nldi_basin(nldi_feature),
  nhd_fline = sf::st_as_sf(dplyr::filter(sf::read_sf(nhdp, "NHDFlowline_Network"), 
                                         ftype != "ArtificialPath")),
  nhd_cat = sf::read_sf(nhdp, "CatchmentSP"),
  nhd_area = sf::read_sf(nhdp, "NHDArea"),
  nhd_wbody = sf::read_sf(nhdp, "NHDWaterbody"),
  nhd_bbox = sp_bbox(st_transform(nhd_fline_p, 4326)),
  outlet_name = nhd_fline_p$gnis_name[which(nhd_fline_p$hydroseq == min(nhd_fline_p$hydroseq))],
  usgs_sites = gsub(pattern = "USGS-",
                     replacement = "", 
                     x = nwissite$identifier),
  whatFlow = dataRetrieval::whatNWISdata(siteNumber = usgs_sites,
                                         parameterCd = "00060",
                                         statCd = "00003",
                                         service="dv") %>% 
    filter(end_date >= Sys.Date()-1) %>% 
    arrange(desc(count_nu)),
  flowData = dataRetrieval::readNWISdv(siteNumbers = whatFlow$site_no[1], "00060"),
  whatWQ = dataRetrieval::whatNWISdata(siteNumber = usgs_sites,
                        service = "qw") %>% 
    filter(!is.na(parm_cd),
           count_nu > 150),
  Sample = EGRET::readNWISSample(siteNumber = whatFlow$site_no[1], parameterCd = "00095") %>% 
    filter(ConcHigh > 10,
           !duplicated(Date)),
  Daily = EGRET::readNWISDaily(siteNumber = whatFlow$site_no[1],
                               startDate = min(Sample$Date), 
                               endDate = max(Sample$Date)),
  INFO = EGRET::readNWISInfo(whatFlow$site_no[1], parameterCd = "00095", interactive = FALSE),
  eList = EGRET::mergeReport(INFO = INFO, Daily = Daily, Sample = Sample) %>% 
    EGRET::modelEstimation() %>% 
    EGRET::blankTime(startBlank = "1991-10-01", 
                     endBlank = "2008-01-01"),
  simple_site = list(featureSource = "nwissite", 
               featureID = paste0("USGS-", whatFlow$site_no[1])),
  simple_UT = navigate_nldi(simple_site, "upstreamTributaries", ""),
  simple_UT_site = navigate_nldi(simple_site, "upstreamTributaries", "nwissite"),
  simple_nhdp = nhdplusTools::subset_nhdplus(simple_UT$nhdplus_comid, 
                                             output_file = file_out("data/simple_nhdp.gpkg"), 
                                             nhdplus_data = "download", 
                                             status = TRUE, 
                                             overwrite = TRUE),
  flowline = sf::read_sf(simple_nhdp, "NHDFlowline_Network"),
  catchment = set_precision(sf::read_sf(simple_nhdp, "CatchmentSP"), 10000),
  boundary = st_union(st_geometry(catchment)),
  plot_box = sp_bbox(st_transform(catchment, 4326))
)

make(plan)
