library(dplyr) 
library(tidyr)
library(jsonlite)
library(stringr)
library(recommenderlab)

setwd("/Users/omerk/Desktop/University/Sem 6/BDA/project")
# load("recommender_data.RData")

business<-stream_in(file("data/yelp_training_set_business.json"),verbose = F) # 11537
user <-stream_in(file("data/yelp_training_set_user.json"),verbose = F) # 229907
review <-stream_in(file("data/yelp_training_set_review.json"),verbose = F) # 43873

# DATA TRANSFORMATIONS

#------BUSINESS-------#
# Selected only open businesses. 
# Deleted unused columns. 
# Filtered food/beverage categories. 
# Factored categories.

business <- business %>% 
  filter(open == "TRUE") %>% 
  select(-open, -neighborhoods, -type, -stars, -review_count) %>% 
  mutate(categories = sapply(categories, toString)) 
nrow(business) # 10313

category_filter <- "Bar|Bars|Beer|Wine|Cocktail|Pub|Pubs|Pork|Hot Dogs|Gastropub|Breweries|Champagne|Spirits|Alcohol|Dive Bars|Lounges"

## Filter businesses using filter 
business <- business %>% 
  filter(!str_detect(categories, regex(category_filter, ignore_case = TRUE))) %>% 
  mutate(categories = as.factor(categories))
nrow(business) # 9446

business <- business %>%
  filter(str_detect(categories, regex("Restaurants|Cafe|Food", ignore_case = TRUE)))
nrow(business) # 4279

#-------REVIEW--------#
# Used business subset to filter out-of-scope reviews.
# Deleted unused columns. 

review <- review %>% 
  filter(business_id %in% business$business_id) %>% 
  select(-type)
nrow(review) # 126038

#--------USER---------#
# Used business subset to filter out-of-scope reviews.
# Deleted unused columns.
# Took random sample of 10k users.
# Dropped aggregate data and recalculated avgs based on subset. 

## filter data in business
user <- user %>% 
  filter(user_id %in% review$user_id) %>% 
  select(-type) %>%
  mutate(user_id = as.character(user_id))

set.seed(50)
user<-sample_n(user, 10000) # 30,645 to 10,000

# filter reviews again
review <- review %>% 
  filter(user_id %in% user$user_id)
nrow(review) # 39551

business <- business %>% 
  filter(business_id %in% review$business_id) 
nrow(business) # 3865

# merge user and review tables and aggregate
user <- user %>% 
  select(user_id, name) %>% 
  inner_join(review, by="user_id") %>% 
  select(-date, -review_id) %>%
  group_by(user_id, name) %>% 
  rename(user_name = name) %>%
  summarize(
    review_count = n(), 
    average_stars = round(mean(stars), 2)
  ) %>%
  ungroup()

# is_grouped_df(user)

# BUILDING THE FINAL DATAFRAME 

## Created our main dataframe business and review dataframes.
## Set `Business_ID` as unique keys. 
## Set numeric user/item keys for UBCF 

df <- business %>% 
  inner_join(review, by="business_id") %>% 
  transform(userID=match(user_id, unique(user_id)))%>%
  transform(itemID=match(business_id, unique(business_id)))


## PART 2 - Building the ratings matrix

# spread data from long to wide format 
matrix_data <- df %>% select(userID, itemID, stars) %>% spread(itemID, stars)
# set row names (labels) to userid and remove it from the columns
rownames(matrix_data)<-matrix_data$userID 
matrix_data <-matrix_data %>% select(-userID) 

# randomize dataframe, make vals numeric and create a realRatingMatrix
set.seed(1)
matrix_data <- matrix_data[sample(nrow(matrix_data)),]
ui_mat <- matrix_data %>% as.matrix()
ui_mat <- as(ui_mat,"realRatingMatrix")

## PART 3
# using recommenderlab, create UBCF recommender with z-score normalized data using cosine similarity
UB <- Recommender(ui_mat, "UBCF", param=list(normalize = "Z-score", method="Cosine"))
p <- predict(UB, ui_mat, type = "topNList", n = 50)

save.image(file = "recommender_data.RData")