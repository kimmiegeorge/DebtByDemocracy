############################
# ravenpack regressions and plots 
############################
# trace(stargazer:::.stargazer.wrap, edit = T) 7054
#_______________Set up________________

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, haven)

plots_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/figures"
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation"
data_wd <- "~/Dropbox/Voting on Bonds/Data/News"


data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
data <- as.data.table(data)
issuers <- data[, list(issuer_long_name = first(issuer_long_name), 
                       fips = first(fips)), .(seed_issuer_id)]

#_______________Issuance Level________________
issuance_lvl = fread(paste0(data_wd, '/Issuance_Lvl_News_With_Lagged_News_20250903.csv'))
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]
setnames(issuance_lvl, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
setnames(issuance_lvl, 'total_rp_articles_12_10', 'total_rp_articles_12_0')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]
issuance_lvl = issuance_lvl[city_rev_vote == 0]

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
issuance_lvl[, total_rp_articles_18_12_raw := total_rp_articles_18_12]
issuance_lvl[, total_rp_articles_18_12 := log(1+total_rp_articles_18_12)]
issuance_lvl[, total_rp_articles_12_6_raw := total_rp_articles_12_6]
issuance_lvl[, total_rp_articles_12_6 := log(1+total_rp_articles_12_6)]
issuance_lvl[, total_rp_articles_30_24_raw := total_rp_articles_30_24]
issuance_lvl[, total_rp_articles_30_24 := log(1+total_rp_articles_30_24)]


issuance_lvl[, rolling_sum_monthly_article_count_6 := log(1+rolling_sum_monthly_article_count_6)]
issuance_lvl[, rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]


# quarter 
issuance_lvl[, quarter := ifelse(month %in% c(1,2,3), 1, 
                                 ifelse(month %in% c(4,5,6), 2, 
                                        ifelse(month %in% c(7,8,9), 3, 4)))]
issuance_lvl[, yq := paste0(year, quarter)]

issuance_lvl[, ym := paste0(year, month)]

issuance_lvl[, unique_sources_6 := log(1+ unique_sources_6)]
issuance_lvl[, unique_sources_12_raw := unique_sources_12]
issuance_lvl[, unique_sources_12 := log(1+ unique_sources_12)]

# add issuer name 
#issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]

# drop school boards
issuance_lvl[, school_adj := grepl('BRD ED',issuer_long_name )]
issuance_lvl <- issuance_lvl[school_adj == 0]

#_______________Plot________________
event_data = fread(paste0(data_wd, '/City_Month_DF_For_Event_Plot_GO_Only.csv'))
event_data[, quarter := ((event_month + 24) %/% 3) + 1]
event_data[, quarter := quarter - 9]
event_data_quarter = event_data[, list(rp_article_count = mean(rp_article_count)), .(city_go_vote, quarter)]

data_city_0 = event_data[city_go_vote == 0]
data_city_1 = event_data[city_go_vote == 1]
loadfonts()
plot = ggplot() +                                                                                                         
  geom_line(data = data_city_0[event_month %in% c(-12:12)], aes(x = event_month, y = rp_article_count, color = "No"), size = 1.25) +                                                                                                 
  geom_line(data = data_city_1[event_month %in% c(-12:12)], aes(x = event_month, y = rp_article_count, color = "Yes"), size = 1.25) +                                                                                                 
  labs(x = "Event Month", y = "Monthly Article Count", title = "Article Counts Relative to Debt Issuance") +              
  #ylim(0, 0.2) +                                                                                                         
  scale_color_manual(values = c("skyblue2", "salmon2"), name = "City GO Vote") +                                          
  theme_minimal() #  +  
#theme(text = element_text(family =  "Times New Roman"))
#_______________descriptives________________

desc <- issuance_lvl[go_unlim_bond_issuance == 1, .(total_rp_articles_12_0_raw, total_rp_articles_6_0_raw, 
                         total_rp_articles_1_1_raw,
                        unique_sources_12)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Mean = mean(col, na.rm = TRUE),
             Std = sd(col, na.rm = TRUE),
             Min = min(col, na.rm = TRUE),
             p1 = quantile(col, probs = 0.01, na.rm = TRUE),
             Median = median(col, na.rm = TRUE),
             p99 = quantile(col, probs = 0.99, na.rm = TRUE),
             Max = max(col, na.rm = TRUE),
             N = sum(!is.na(col)))
  return(stats)
}), .SDcols = colnames(desc)]
desc_col <- transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("variable", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/Ravenpack Descriptives.tex')


stargazer(desc, type = 'latex', summary = T, iqr = T, min.max = F, median = T, no.space = T,
          covariate.labels = c('Issuance Month Articles (raw)', '6 Mo Issuance Articles (raw)',
                               'Issuance Month Articles (ln)', '6 Mo Issuance Articles (ln)',
                               'Abnormal Issuance Month Articles', 'Abnormal 6 Mo Issuance Articles',
                               'I(Vote)', 'Amount', 'GDP', 'Pers Inc', 'Percap Inc', 'Emp'),
            table.placement = 'H', out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/news.tex'))
#_______________descriptives________________
# y, m fixed effects, state and state+purpose cluster 
# ym fixed effects, state and state+purpose cluster 
# y, q fixed effects, state and state+purpose cluster 
# yq fixed effects, state and state+purpose cluster 
test_coef = function(model, var1, var2){
  # Check the class of the model to determine which test to use
  if (inherits(model, "felm")) {
    # For felm models from lfe package
    hyp_test = wald(model, paste0(var1, ' = ', var2))
    chi_sq = hyp_test$Chisq[2]
    p_val = hyp_test$`Pr(>Chisq)`[2]
  } else {
    # Use linearHypothesis from car package for fixest models
    hyp_test = car::linearHypothesis(model, paste0(var1, ' - ', var2, ' = 0'))
    chi_sq = hyp_test$Chisq[2]
    p_val = hyp_test$`Pr(>Chisq)`[2]
  }
  
  return(c(round(chi_sq, 3), round(p_val, 3)))
}

issuance_lvl[, supermajority := ifelse(state %in% c('CA', 'ID', 'MO', 'ND', 'OK', 'SD', 'WA'), 1, 0)]
issuance_lvl[, majority := ifelse(city_go_vote == 1 & supermajority == 0, 1, 0)]
issuance_lvl[, total_rp_articles_6_0_win := Winsorize(total_rp_articles_6_0_raw, val = quantile(total_rp_articles_6_0_raw, probs = c(0.01, 0.99)))]
issuance_lvl[, total_rp_articles_12_0_win := Winsorize(total_rp_articles_12_0_raw, val = quantile(total_rp_articles_12_0_raw, probs = c(0.01, 0.99)))]
r1 <- feols(total_rp_articles_12_0 ~ city_go_vote  + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1], vcov = vcov_cluster(~fips))
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + unique_sources_12 + ln_amount  + ln_gdp + ln_pop  +ln_pers_inc + ln_employment|year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1,r2,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          dep.var.caption = "",
          title = "Issuance Level Counts of Articles",
          dep.var.labels = c("Total Articles [-12, 0]", "Total Articles [-6, 0]", "Total Articles [-1, +1]"),
          covariate.labels = c("Vote",  "Number of Sources","ln(Size)", "County ln(GDP)","County ln(Pop)", "County ln(Pers Inc)", "County ln(Emp)"),
          add.lines = list(c("Time FE", "Year", "Year", "Year", "Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "County", 'County', "County", 'County')),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/Article Counts Full Sample.tex')
          

r1 <- feols(total_rp_articles_6_0~ supermajority + majority  + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1],vcov = vcov_cluster(~fips))
summary(r1)
test_coef(r1, 'supermajority', 'majority')

issuance_lvl[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]
r1 <- feols(total_rp_articles_12_0~ city_go_vote*go  + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl,vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(total_rp_articles_6_0~ city_go_vote*go  + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl,vcov = vcov_cluster(~fips))
summary(r2)

etable(r1, r2, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(total_rp_articles_12_0 ='Total Articles [-12, 0]',
                total_rp_articles_6_0 = 'Total Articles [-6, 0]',
                unique_sources_12 = 'Num Sources',
                city_go_vote = 'Vote',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                year = 'Year',
                go = 'GO',
                purp_broad = 'Purpose'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/full_sample_alt_articles.tex', 
       replace = TRUE)





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




#_______________Time Series________________
time_series <- as.data.table(read_parquet('~/Dropbox/Voting on Bonds/Data/News/Full_City_Month_Data_Headline_Filter_250903.gzip'))
time_series[, ym := paste0(year, month)]
time_series <- time_series[!is.na(city_go_vote)]
time_series <- time_series[city_rev_vote == 0]




time_series[, coverage := ifelse(rp_article_count > 0, 1, 0)]
time_series[, log_rp_articles := log(1+rp_article_count)]
time_series[, go_any_issuance_next_12mth := ifelse(go_unlim_bond_issuance_next_12mth == 1 | go_lim_bond_issuance_next_12mth == 1, 1, 0)]
time_series[, go_any_issuance_next_6mth := ifelse(go_unlim_bond_issuance_next_6mth == 1 | go_lim_bond_issuance_next_6mth == 1, 1, 0)]
r1 <- feols(coverage ~ go_any_issuance_next_12mth*city_go_vote + 
              rev_bond_issuance_next_12mth*city_go_vote + ln_gdp + ln_pop + ln_percap_inc + ln_employment + bond_issuance_month|state + ym , data = time_series[!(state %in% c('MI', 'OH', 'WA'))], vcov = vcov_cluster(~fips))
summary(r1)

borders <- unique(articles[, .(seed_issuer_id, group)])
time_series_border <- borders[time_series, on = .(seed_issuer_id),  allow.cartesian = T]
time_series_border <- time_series_border[!is.na(group)]
time_series_border[, group_ym := paste0(group, ym)]
r1 <- feols(coverage ~ go_any_issuance_next_6mth*city_go_vote + 
              rev_bond_issuance_next_6mth*city_go_vote + ln_gdp + ln_pop + ln_percap_inc + ln_employment + bond_issuance_month| group + ym, data = time_series_border[], vcov = vcov_cluster(~fips))
summary(r1)
