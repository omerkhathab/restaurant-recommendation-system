library(plumber)
library(dplyr)
library(recommenderlab)
library(jsonlite)
library(stringr)

setwd("/Users/omerk/Desktop/University/Sem 6/BDA/project")
load("recommender_data.RData")

#* @apiTitle Restaurant Recommendation API

#* Get restaurant recommendations for a specific user
#* @param user_id The ID of the user to get recommendations for
#* @param n Number of recommendations to return (default: 5)
#* @post /recommend
function(user_id, n = 5) {
  n <- as.numeric(n)
  
  # 1. Check if user_id exists in rownames
  if (!(user_id %in% rownames(ui_mat))) {
    return(list(error = "User ID not found in rating matrix."))
  }
  
  # 2. Extract user row
  user_row <- ui_mat[user_id, , drop = FALSE]
  
  # 3. Check if user has any ratings
  if (sum(as(user_row, "matrix"), na.rm = TRUE) == 0) {
    return(list(error = "User has no ratings. Cannot generate recommendations."))
  }
  
  # 4. Predict ratings using UBCF
  user_pred <- predict(UB, user_row, type = "ratings")
  pred_matrix <- as(user_pred, "matrix")
  
  # 5. Check if predictions contain only NAs
  if (all(is.na(pred_matrix))) {
    return(list(error = "No recommendations could be predicted for this user."))
  }
  
  # 6. Sort predictions and get top N (e.g., 5)
  top_recs <- sort(pred_matrix[1, ], decreasing = TRUE)
  top_recs <- top_recs[!is.na(top_recs)]  # Remove NAs
  top_biz_ids_int <- as.integer(names(top_recs)[1:n])
  
  item_id_mapping <- df %>% 
    select(itemID, business_id) %>% 
    distinct()
  
  # 7. Map item IDs to business IDs
  actual_business_ids <- item_id_mapping %>%
    filter(itemID %in% top_biz_ids_int) %>%
    pull(business_id)
  
  if (length(actual_business_ids) == 0) {
    return(list(error = "No mapped business_ids found for predicted items."))
  }
  
  # 8. Get metadata for recommended businesses
  recommended_businesses <- business %>%
    filter(business_id %in% actual_business_ids)
  
  if (nrow(recommended_businesses) == 0) {
    return(list(error = "No business metadata found for recommendations."))
  }
  
  # 9a. Add review stats to recommended businesses
  business_ratings <- review %>%
    filter(business_id %in% actual_business_ids) %>%
    group_by(business_id) %>%
    summarize(
      avg_rating = mean(stars, na.rm = TRUE),
      review_count = n()
    ) %>%
    ungroup()
  
  # 9b. Join review stats with business info
  results <- recommended_businesses %>%
    inner_join(business_ratings, by = "business_id") %>%
    select(business_id, name, city, state, full_address, categories, avg_rating, review_count)
  return(results)
}

#* Get restaurant recommendations based on keywords
#* @param tags Comma-separated list of keywords (e.g., "indian, buffet")
#* @param city_name Optional city filter
#* @param n Number of recommendations to return (default: 5)
#* @post /recommend_by_tags
function(tags, city_name = NULL, n = 5) {
  n <- as.numeric(n)
  
  # Split tags into vector
  tag_list <- strsplit(tags, ",")[[1]]
  tag_list <- trimws(tag_list)
  
  # Create regex pattern for all tags with OR operator
  tag_pattern <- paste(tag_list, collapse = "|")
  
  # Filter businesses by tags
  matching_businesses <- business %>%
    filter(str_detect(categories, regex(tag_pattern, ignore_case = TRUE)))
  
  # Apply city filter if provided
  if (!is.null(city_name)) {
    city_name <- tolower(trimws(city_name))
    matching_businesses <- matching_businesses %>%
      filter(str_detect(tolower(city), regex(city_name, ignore_case = TRUE)))
  }

  # If no matches found, return error
  if (nrow(matching_businesses) == 0) {
    return(list(error = "No restaurants found matching these criteria"))
  }
  
  # Get review data for matching businesses
  business_ratings <- df %>%
    filter(business_id %in% matching_businesses$business_id) %>%
    group_by(business_id) %>%
    summarize(
      avg_rating = mean(stars, na.rm = TRUE),
      review_count = n()
    ) %>%
    ungroup()
  
  # Join with business data
  results <- matching_businesses %>%
    inner_join(business_ratings, by = "business_id") %>%
    arrange(desc(avg_rating), desc(review_count)) %>%
    select(business_id, name, city, state, full_address, categories, avg_rating, review_count) %>%
    head(n)
  
  return(results)
}

#* Get preferred categories (interests) for a user
#* @param user_index The ID of the user
#* @get /user_features
function(user_index) {
  
  user_id_map <- df %>%
    select(userID, user_id) %>%
    distinct()
  
  string_id <- user_id_map %>%
    filter(userID == as.integer(user_index)) %>%
    pull(user_id)

  name <- user %>%
    filter(string_id == user_id) %>%
    pull(user_name)
  
  # 1. Filter reviews where the user rated 4 or 5 stars
  user_reviews <- review %>%
    filter(.data$user_id == user_id, stars >= 4)
  
  # If user has no high ratings, return early
  if (nrow(user_reviews) == 0) {
    return(list(
      user_id = user_index,
      user_name = name,
      message = "No high-rated reviews found for this user.",
      user_features = character(0)
    ))
  }
  
  # 2. Join with business info
  user_businesses <- user_reviews %>%
    inner_join(business, by = "business_id")
  
  # 3. Extract and clean categories
  preferred_categories <- user_businesses %>%
    pull(categories) %>%
    str_split(",\\s*") %>%    # split each row's categories into a list
    unlist() %>%              # flatten into a vector
    tolower() %>%
    str_trim() %>%
    table() %>%               # count frequency of each category
    sort(decreasing = TRUE) %>%
    head(10)                  # get top 10 categories
  
  # 4. Return top categories as JSON
  return(list(
    user_id = user_index,
    user_name = name,
    user_features = names(preferred_categories),
    frequencies = as.integer(preferred_categories)
  ))
}

#' @filter cors
cors <- function(req, res) {
  
  res$setHeader("Access-Control-Allow-Origin", "*")
  
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods","*")
    res$setHeader("Access-Control-Allow-Headers", req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
    res$status <- 200 
    return(list())
  } else {
    plumber::forward()
  }
}
# pr("api.R") %>% pr_run(port = 8000)