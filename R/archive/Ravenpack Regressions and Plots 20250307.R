############################
# ravenpack regressions and plots 
############################
# trace(stargazer:::.stargazer.wrap, edit = T) 7054
#_______________Set up________________

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, haven)

plots_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/figures"
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_ravenpack"
data_wd <- "~/Dropbox/Voting on Bonds/Data/News"

#_______________Full Data________________
full_data = read_parquet(paste0(data_wd, '/Full_City_Month_Data_Headline_Filter.gzip'))
#full_data = read_parquet(paste0(data_wd, '/Full_City_Month_Data_All_RP_Articles_Included.gzip'))
full_data = as.data.table(full_data)
full_data[, rp_article_count_raw := rp_article_count]
full_data[, rp_article_count := log(1+rp_article_count)]
full_data = full_data[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
full_data[, year_month := paste0(year, '_', month)]
full_data = full_data[!is.na(city_go_vote)]

states = unique(full_data[, .(seed_issuer_id, state)])



#_______________Issuance Level________________
issuance_lvl = fread(paste0(data_wd, '/Issuance_Lvl_News_With_Lagged_News_20250309.csv'))
setnames(issuance_lvl, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
setnames(issuance_lvl, 'total_rp_articles_12_10', 'total_rp_articles_12_0')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]

issuance_lvl[, issuance_month_total_articles_raw := issuance_month_total_articles]
issuance_lvl[, issuance_month_total_articles := log(1 + issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_1_1_raw := total_rp_articles_1_1]
issuance_lvl[, total_rp_articles_1_1 := log(1+total_rp_articles_1_1)]
issuance_lvl[, total_rp_articles_1_0_raw := total_rp_articles_1_0]
issuance_lvl[, total_rp_articles_1_0 := log(1+total_rp_articles_1_0)]
issuance_lvl[, total_rp_articles_6_0_raw := total_rp_articles_6_0]
issuance_lvl[, total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl[, total_rp_articles_6_1_raw := total_rp_articles_6_1]
issuance_lvl[, total_rp_articles_6_1 := log(1+total_rp_articles_6_1)]
issuance_lvl[, total_rp_articles_12_0_raw := total_rp_articles_12_0]
issuance_lvl[, total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]


# quarter 
issuance_lvl[, quarter := ifelse(month %in% c(1,2,3), 1, 
                                 ifelse(month %in% c(4,5,6), 2, 
                                        ifelse(month %in% c(7,8,9), 3, 4)))]
issuance_lvl[, yq := paste0(year, quarter)]

issuance_lvl[, ym := paste0(year, month)]

issuance_lvl[, rolling_avg_monthly_article_count_12_raw := rolling_avg_monthly_article_count_12]
issuance_lvl[, rolling_avg_monthly_article_count_12 := log(1+ rolling_avg_monthly_article_count_12)]
issuance_lvl[, rolling_avg_monthly_article_count_6_raw := rolling_avg_monthly_article_count_6]
issuance_lvl[, rolling_avg_monthly_article_count_6 := log(1+ rolling_avg_monthly_article_count_6)]
issuance_lvl[, rolling_avg_monthly_article_count_6_lag6_raw := rolling_avg_monthly_article_count_6_lag6]
issuance_lvl[, rolling_avg_monthly_article_count_6_lag6 := log(1+ rolling_avg_monthly_article_count_6_lag6)]
issuance_lvl[, rolling_avg_monthly_article_count_12_lag6_raw := rolling_avg_monthly_article_count_12_lag6]
issuance_lvl[, rolling_avg_monthly_article_count_12_lag6 := log(1+ rolling_avg_monthly_article_count_12_lag6)]

issuance_lvl[, unique_sources_6_raw := unique_sources_6]
issuance_lvl[, unique_sources_6 := log(1+unique_sources_6)]

issuance_lvl[, unique_sources_12_raw := unique_sources_12]
issuance_lvl[, unique_sources_12 := log(1+unique_sources_12)]

issuance_lvl[, articles_6_0_scaled := ifelse(unique_sources_6_raw != 0, total_rp_articles_6_0_raw/unique_sources_6_raw, 0)]
issuance_lvl[, articles_12_0_scaled := ifelse(unique_sources_12_raw != 0, total_rp_articles_12_0_raw/unique_sources_12_raw, 0)]

#_______________Plot________________
event_data = fread(paste0(data_wd, '/City_Month_DF_For_Event_Plot_Unlim_GO_Only.csv'))
event_data[, quarter := ((event_month + 24) %/% 3) + 1]
event_data[, quarter := quarter - 9]
event_data_quarter = event_data[, list(rp_article_count = mean(rp_article_count)), .(city_go_vote, quarter)]
data_city_0 = event_data[city_go_vote == 0]
data_city_1 = event_data[city_go_vote == 1]

plot = ggplot() + 
  geom_line(data = data_city_0, aes(x = event_month, y = rp_article_count, color = "City GO Vote = 0")) + 
  geom_line(data = data_city_1, aes(x = event_month, y = rp_article_count, color = "City GO Vote = 1")) + 
  labs(x = "Event Month", y = "Monthly Article Count", title = "Article Counts Relative to Debt Issuance (GO Debt Only)") + 
  #ylim(0, 0.2) +
  scale_color_manual(values = c("skyblue2", "salmon2")) + 
  theme_minimal()

#_______________descriptives________________

desc <- issuance_lvl[, .(issuance_month_total_articles_raw, total_articles_6_0_raw, total_articles
                         issuance_month_total_articles, total_rp_articles_6mo_window_event,
                         abnormal_rp_article_count_issuance_month, abnormal_rp_article_count_6mo, 
                         city_go_vote, 
                         ln_amount, ln_gdp, ln_pers_inc, ln_percap_inc, ln_employment)]


stargazer(desc, type = 'latex', summary = T, iqr = T, min.max = F, median = T, no.space = T,
          covariate.labels = c('Issuance Month Articles (raw)', '6 Mo Issuance Articles (raw)',
                               'Issuance Month Articles (ln)', '6 Mo Issuance Articles (ln)',
                               'Abnormal Issuance Month Articles', 'Abnormal 6 Mo Issuance Articles',
                               'I(Vote)', 'Amount', 'GDP', 'Pers Inc', 'Percap Inc', 'Emp'),
            table.placement = 'H', out = paste0(tables_wd, '/Descriptives_IssuanceLvl.tex'))
#_______________descriptives________________
# y, m fixed effects, state and state+purpose cluster 
# ym fixed effects, state and state+purpose cluster 
# y, q fixed effects, state and state+purpose cluster 
# yq fixed effects, state and state+purpose cluster 


r1 <- felm(articles_6_0_scaled ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(articles_12_0_scaled ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1,r2,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-1, 0]", "Total Articles [-6, 0]"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp", "Media Coverage [-7, -1]"),
          add.lines = list(c("Time FE", "Year", "Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", 'State')),
          out = paste0(tables_wd, '/Article Counts FINAL.tex')
          )

r1 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r4 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r5 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r6 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r7 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r8 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1,r2,r3,r4,r5,r6,r7,r8,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-1, +1]"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp"),
          add.lines = list(c("Time FE", "Y,M", "Y,M", "YM", "YM", "Y,Q", "Y,Q", "YQ", "YQ"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM")),
          out = paste0(tables_wd, '/Article Counts FE and Cluster Options (6 Month Prior Articles).tex')
)

r1 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])

