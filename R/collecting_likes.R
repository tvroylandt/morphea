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
    urls_expanded_url,
    ext_media_url,
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
df_quoted_tweets <- df_fav %>%
  filter(is_quote == TRUE) %>%
  select(quoted_status_id) %>%
  pull() %>%
  lookup_tweets() 

df_fav_quoted_users_infos <- df_quoted_tweets %>%
  users_data() %>%
  select(user_id, screen_name, name) %>%
  distinct() %>%
  rename_all(function(x)
    paste0("quoted_", x))

df_quoted_media <- df_quoted_tweets %>%
  select(status_id,
         urls_expanded_url) %>%
  rename(quoted_urls_expanded_url = urls_expanded_url)

# joining all infos + cleaning lists
df_fav_clean <- df_fav_select %>%
  left_join(df_fav_users_infos, by = "user_id") %>%
  left_join(df_fav_quoted_users_infos, by = "quoted_user_id") %>%
  left_join(df_quoted_media, by = c("quoted_status_id" = "status_id")) %>%
  rtweet::flatten() %>%
  mutate(
    link_tw = paste0("https://twitter.com/", screen_name, "/status/", status_id),
    quoted_link_tw = paste0(
      "https://twitter.com/",
      quoted_screen_name,
      "/status/",
      quoted_status_id
    ),
    urls_expanded_url = str_remove(urls_expanded_url, quoted_link_tw),
    urls_expanded_url = str_trim(urls_expanded_url, "both")
  ) %>% 
  arrange(desc(created_at))

# Google Auth -------------------------------------------------------------
# need to allow the API for the sheet
googlesheets4::gs4_auth(email = Sys.getenv("GOOGLE_MAIL"),
         path = "secret/morphea_token.json")

# # Importing Google Sheets -------------------------------------------------
# df_tw_sheet <-
#   read_sheet(Sys.getenv("SHEET_PATH"),
#              sheet = "tw_fav")
# 
# # Merging data ------------------------------------------------------------
# df_fav_tw_supp <- df_fav_clean %>%
#   filter(!status_id %in% unique(df_tw_sheet$status_id))
# 
# df_tw_sheet_full <- df_tw_sheet %>%
#   bind_rows(df_fav_tw_supp) %>% 
#   arrange(desc(created_at))

# Categorising data -------------------------------------------------------

# Intermediate save -------------------------------------------------------
# Saved as artifact
write_csv(df_fav_clean, "tw_fav.csv")

# Exporting to Google Sheets ----------------------------------------------
write_sheet(df_fav_clean,
            ss = Sys.getenv("SHEET_PATH"),
            sheet = "tw_fav")
