# ----------------------- #
# Collecting likes #
# ----------------------- #

library(rtweet)
library(tidyverse)
library(googlesheets4)

# Twitter Auth ------------------------------------------------------------
token <- create_token(
  app = "morphea_tv",
  consumer_key = Sys.getenv("TW_API_KEY"),
  consumer_secret = Sys.getenv("TW_SECRET_KEY"),
  access_token = Sys.getenv("TW_ACCESS_TOKEN"),
  access_secret = Sys.getenv("TW_SECRET_TOKEN")
)

# Importing likes ---------------------------------------------------------
df_fav <- get_favorites(user = "tvroylandt", n = 3000)

# Cleaning the data -------------------------------------------------------
# columns selection
df_fav_select <- df_fav %>%
  select(
    user_id,
    status_id,
    created_at,
    text,
    is_quote,
    quoted_text,
    quoted_status_id,
    quoted_user_id,
    hashtags,
    urls_url,
    media_url,
    favorite_count,
    retweet_count
  )

# infos about users
df_fav_users_infos <- df_fav %>%
  users_data() %>%
  select(user_id,
         screen_name,
         name,
         followers_count,
         friends_count,
         description,
         url) %>%
  distinct()

# infos about quoted users
df_fav_quoted_users_infos <- df_fav %>%
  filter(is_quote == TRUE) %>%
  select(quoted_status_id) %>%
  pull() %>%
  lookup_tweets() %>%
  users_data() %>%
  select(user_id, screen_name, name) %>%
  distinct() %>%
  rename_all(function(x)
    paste0("quoted_", x))

# joining all infos + cleaning list
df_fav_clean <- df_fav_select %>%
  left_join(df_fav_users_infos, by = "user_id") %>%
  left_join(df_fav_quoted_users_infos, by = "quoted_user_id") %>%
  mutate(
    hashtags = paste0(hashtags),
    hashtags = str_remove_all(hashtags, 'c\\(|\\)|"'),
    hashtags = str_replace_all(hashtags, ", ", " \n"),
    hashtags = case_when(hashtags != "NA" ~ hashtags),
    urls_url = paste0(urls_url),
    urls_url = str_remove_all(urls_url, 'c\\(|\\)|"'),
    urls_url = str_replace_all(urls_url, ", ", " \n"),
    urls_url = case_when(urls_url != "NA" ~ urls_url)
  ) %>%
  unnest(cols = c(media_url)) %>%
  group_by(status_id) %>%
  mutate(n = row_number()) %>%
  pivot_wider(values_from = c(media_url), names_from = n) %>%
  ungroup()

# Google Auth -------------------------------------------------------------
# Sheet is public with the link here
gs4_deauth()

# Importing Google Sheets -------------------------------------------------
df_tw_sheet <-
  read_sheet(Sys.getenv("SHEET_PATH"),
             sheet = "tw_fav")

# Merging data ------------------------------------------------------------
df_fav_tw_supp <- df_fav_clean %>%
  filter(!status_id %in% unique(df_tw_sheet$status_id))

df_tw_sheet_full <- df_tw_sheet %>%
  bind_rows(df_fav_tw_supp)

# Categorising data -------------------------------------------------------



# Intermediate save -------------------------------------------------------
# Saved as artifact
write_csv(df_tw_sheet_full, "tw_fav.csv")

# Exporting to Google Sheets ----------------------------------------------
write_sheet(df_tw_sheet_full,
            ss = Sys.getenv("SHEET_PATH"),
            sheet = "tw_fav")
