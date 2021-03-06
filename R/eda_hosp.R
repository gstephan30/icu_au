heute <- gsub("-", "", Sys.Date())
dest_file <- paste0("data_raw/", heute, "_data.zip")
download.file("https://covid19-dashboard.ages.at/data/data.zip", 
              destfile = dest_file, 
              mode = "wb")

library(dplyr)
list.files("data_raw/", pattern = "data.zip", full.names = TRUE) %>% 
  as_tibble() %>% 
  arrange(desc(value)) %>% 
  slice(1) %>% 
  pull() %>% 
  unzip(., exdir = "data_recent/")


library(readr)
library(lubridate)
library(ggplot2)
theme_set(theme_light())
data_aut <- read_csv2("data_recent/Hospitalisierung.csv") %>% 
  janitor::clean_names() %>%
  mutate(covid_perc = intensiv_betten_bel_covid19/intensiv_betten_kap_ges*100,
         meldedatum = dmy_hms(meldedatum),
         bundesland_id = as.character(bundesland_id)) %>% 
  filter(bundesland_id != "10") 

data_aut %>% 
  ggplot(aes(meldedatum, covid_perc, group = bundesland, color = bundesland)) +
  geom_line() 

# install.packages('maptools')
# install.packages("gpclib", type="source")
# install.packages("rgdal")
# library(rgdal)
# library(maptools)
# if (!require(gpclib)) install.packages("gpclib", type="source")
# gpclibPermit()
# aut_shp <- raster::getData("GADM", country = "AUT", level = 1)
aut_shp <- readRDS("gadm36_AUT_1_sp.rds")
aut_tidy <- aut_shp %>% broom::tidy(region = "NAME_1")

aut_tidy %>% 
  left_join(
    data_aut %>% 
      group_by(bundesland) %>% 
      filter(meldedatum == max(meldedatum)) %>% 
      rename(id = bundesland) %>% 
      select(id, covid_perc)
  ) %>% 
  ggplot() +
  geom_polygon(aes(long, lat, group = group, fill = covid_perc)) +
  coord_quickmap()

library(lubridate)
avg_aut_data <- data_aut %>% 
  mutate(monat = floor_date(meldedatum, "month"),
         monat = as_date(monat)) %>% 
  group_by(bundesland, monat) %>% 
  summarise(avg_perc = mean(covid_perc)) %>% 
  rename(id = bundesland) %>% 
  select(id, avg_perc, monat)
midpunkt <- (max(avg_aut_data$avg_perc) - min(avg_aut_data$avg_perc)) /2

aut_tidy %>% 
  left_join(
    avg_aut_data
  ) %>% 
  ggplot() +
  geom_polygon(aes(long, lat, group = group, fill = avg_perc)) +
  coord_quickmap() +
  facet_wrap(~monat) +
  theme_void() +
  scale_fill_gradient2(low = "#0081a7", mid = "#fdfcdc", high = "#f07167", midpoint = midpunkt)
