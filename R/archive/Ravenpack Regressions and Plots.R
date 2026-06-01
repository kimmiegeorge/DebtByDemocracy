############################
# ravenpack regressions and plots 
############################
# trace(stargazer:::.stargazer.wrap, edit = T) 7054
#_______________Set up________________

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, haven)

plots_wd <- "/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/figures"
tables_wd <- "/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_ravenpack"
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
issuance_lvl = read_parquet(paste0(data_wd, '/Issuance_Lvl_AbnormalNews_HeadlineFilter.gzip'))
issuance_lvl = as.data.table(issuance_lvl)
setnames(issuance_lvl, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
setnames(issuance_lvl, 'total_rp_articles_12_10', 'total_rp_articles_12_0')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]

issuance_lvl[, issuance_month_total_articles_raw := issuance_month_total_articles]
issuance_lvl[, issuance_month_total_articles := log(1 + issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_1_1_raw := total_rp_articles_1_1]
issuance_lvl[, total_rp_articles_1_1 := log(1+total_rp_articles_1_1)]
issuance_lvl[, total_rp_articles_6_0_raw := total_rp_articles_6_0]
issuance_lvl[, total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl[, total_rp_articles_6_1_raw := total_rp_articles_6_1]
issuance_lvl[, total_rp_articles_6_1 := log(1+total_rp_articles_6_1)]
issuance_lvl[, total_rp_articles_12_0_raw := total_rp_articles_12_0]
issuance_lvl[, total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]

#_______________Plot________________
event_data = fread(paste0(data_wd, '/City_Month_DF_For_Event_Plot.csv'))
event_data[, quarter := ((event_month + 24) %/% 3) + 1]
event_data[, quarter := quarter - 9]
event_data_quarter = event_data[, list(rp_article_count = mean(rp_article_count)), .(city_go_vote, quarter)]
data_city_0 = event_data[city_go_vote == 0]
data_city_1 = event_data[city_go_vote == 1]

plot = ggplot() + 
  geom_line(data = data_city_0, aes(x = event_month, y = rp_article_count, color = "City GO Vote = 0")) + 
  geom_line(data = data_city_1, aes(x = event_month, y = rp_article_count, color = "City GO Vote = 1")) + 
  labs(x = "Event Month", y = "Monthly Article Count", title = "Article Counts Relative to Debt Issuance") + 
  #ylim(0, 0.2) +
  scale_color_manual(values = c("skyblue2", "salmon2")) + 
  theme_minimal()

#_______________Plot________________
event_data = fread(paste0(data_wd, '/City_Month_DF_For_Event_Plot_GO_Only.csv'))
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
desc_vars = full_data[, .(bond_issuance_month, bond_issuance_next_6mth, bond_issuance_next_12mth, 
                          go_unlim_bond_issuance, go_unlim_bond_issuance_next_6mth, go_unlim_bond_issuance_next_12mth, 
                          go_lim_bond_issuance, go_lim_bond_issuance_next_6mth, go_lim_bond_issuance_next_12mth, city_go_vote, 
                          rp_article_count_raw,
                          rp_article_count, ln_employment, ln_percap_inc, ln_pers_inc, ln_pop, ln_gdp)]

stargazer(desc_vars, summary = T, iqr = T, min.max = F, median = T, row.names = F, covariate.labels = c("I(Bond)", "I(Bond 6m)", "I(Bond 12m)", 
                                                                             "I(GO Unlim)", "I(Go Unlim 6m)", "I(GO Unlim 12m)",
                                                                             "I(GO Lim)", "I(Go Lim 6m)", "I(GO Lim 12m)",
                                                                             "I(Vote)", "Number of Articles (raw)", "Number of Articles (ln)", 
                                                                             "Emp (ln)", "Percap Inc (ln)", "Pers Inc (ln)", "Pop (ln)", "GDP (ln)"),
          out = paste0(tables_wd, '/Descriptives.tex'))

#_______________Regs________________
reg1b <- felm(rp_article_count ~ bond_issuance_month + city_go_vote + bond_issuance_month:city_go_vote + bond_issuance_month:ln_bond_amount_current_month|year_month|0|year_month + seed_issuer_id, data = full_data)
reg1b <- felm(rp_article_count ~ go_unlim_bond_issuance + city_go_vote + go_unlim_bond_issuance:city_go_vote + go_unlim_bond_issuance:ln_bond_amount_current_month + go_unlim_bond_issuance:bond_purpose_current_month|year_month|0|year_month + seed_issuer_id, data = full_data)


reg1b <- felm(rp_article_count ~ go_unlim_bond_issuance + go_unlim_bond_issuance:city_go_vote + go_unlim_bond_issuance:ln_bond_amount_current_month + bond_issuance_month:bond_purpose_current_month + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |year_month + seed_issuer_id|0|year_month + seed_issuer_id, data = full_data)
reg2b  <- felm(rp_article_count ~ go_unlim_bond_issuance_next_6mth + go_unlim_bond_issuance_next_6mth:city_go_vote + go_unlim_bond_issuance_next_6mth:ln_bond_amount_current_month  + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp|year_month|0|year_month + seed_issuer_id, data = full_data)
reg3b  <- felm(rp_article_count ~ bond_issuance_next_12mth + bond_issuance_next_12mth:city_go_vote  + bond_issuance_next_12mth:ln_bond_amount_current_month + bond_issuance_next_12mth:bond_purpose_current_month +  ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp|year_month|0|year_month + seed_issuer_id, data = full_data)

stargazer(reg1b, reg2b, reg3b,
          type = "latex",  header = FALSE,  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t",  no.space = T,
          column.sep.width = '-5pt',
          title = 'City-Month Articles and Bond Issuance (City FE)',
          dep.var.labels = c('Number of Articles'),
          add.lines = list(c("Month FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("City FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "City,YM", "City,YM", "City,YM",  "City,YM", "City,YM", "City,YM",  "City,YM", "City,YM", "City,YM")),
          order = c(1, 2, 3, 9, 10, 11, 4, 5, 6, 7,8),
          covariate.labels = c('I(Bond)', 'I(Bond 6m)', 'I(Bond 12m)', 'I(Bond)*I(Vote)',
                               'I(Bond 6m)*I(Vote)', 'I(Bond 12m)*I(Vote)', 
                               'Emp', 'Percap Inc', 'Pers Inc', 'Pop', 'GDP'),
          out = paste0(tables_wd, '/All Bonds City YM Cluster City FE.tex'))


#_______________Regs - bond type ________________
reg1b <- felm(rp_article_count ~ rev_bond_issuance + rev_bond_issuance:city_go_vote + go_unlim_bond_issuance + go_unlim_bond_issuance:city_go_vote + go_lim_bond_issuance + go_lim_bond_issuance:city_go_vote + bond_issuance_month:ln_bond_amount_current_month + bond_issuance_month:bond_purpose_current_month + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |year_month|0|year_month + seed_issuer_id, data = full_data)
reg2b <- felm(rp_article_count ~ rev_bond_issuance_next_6mth + rev_bond_issuance_next_6mth:city_go_vote + go_unlim_bond_issuance_next_6mth + go_unlim_bond_issuance_next_6mth:city_go_vote + go_lim_bond_issuance_next_6mth + go_lim_bond_issuance_next_6mth:city_go_vote + bond_issuance_month:ln_bond_amount_current_month + bond_issuance_month:bond_purpose_current_month + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |year_month|0|year_month + seed_issuer_id, data = full_data)
reg2b <- felm(rp_article_count ~ rev_bond_issuance_next_12mth + rev_bond_issuance_next_12mth:city_go_vote + go_unlim_bond_issuance_next_12mth + go_unlim_bond_issuance_next_12mth:city_go_vote + go_lim_bond_issuance_next_12mth + go_lim_bond_issuance_next_12mth:city_go_vote + bond_issuance_month:ln_bond_amount_current_month + bond_issuance_month:bond_purpose_current_month + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |year_month|0|year_month + seed_issuer_id, data = full_data)




#_______________Regs - Issuance Level ________________
issuance_lvl[, issuance_month_total_articles_raw := issuance_month_total_articles]
issuance_lvl[, total_rp_articles_6mo_window_event_raw := total_rp_articles_6mo_window_event]
issuance_lvl[, issuance_month_total_articles := log(1+issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_6mo_window_event := log(1+total_rp_articles_6mo_window_event)]

#issuance_lvl[, abnormal_rp_article_count_6mo := log(abnormal_rp_article_count_6mo)]
#issuance_lvl[, abnormal_rp_article_count_issuance_month := log(abnormal_rp_article_count_issuance_month)]
desc <- issuance_lvl[, .(issuance_month_total_articles_raw, total_rp_articles_6mo_window_event_raw, 
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

issuance_lvl[, ym := paste0(year, month)]
reg1 <- felm(issuance_month_total_articles ~ city_go_vote|ym + purp_broad|0|purp_broad + state, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|ym + purp_broad|0|purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + purp_broad|0|purp_broad + state, data = issuance_lvl[go_unlim_bond_issuance == 1])

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Issuance Level Counts of Articles',
          dep.var.caption = c("Counts of Articles:"),
          dep.var.labels = c("Issuance Mo", "6 Mo"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc", "Percap Inc", "Emp"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Purpose Indicators", "No", "Yes", "No", "Yes", "No", "Yes"),
                           c("Cluster", "Purpose", "Purpose", "Purpose",  "Purpose", "Purpose", "Purpose")),
          out = paste0(tables_wd, '/Issuance Level Counts Regs.tex')
          )

reg1 <- felm(abnormal_rp_article_count_issuance_month ~ city_go_vote|year|0|use_proceeds, data = issuance_lvl)
reg2 <- felm(abnormal_rp_article_count_issuance_month ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl)
reg3 <- felm(abnormal_rp_article_count_6mo ~ city_go_vote|year|0|use_proceeds, data = issuance_lvl)
reg4 <- felm(abnormal_rp_article_count_6mo ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl)

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Abnormal Issuance Level Counts of Articles',
          dep.var.caption = c("Abnormal Counts of Articles:"),
          dep.var.labels = c("Issuance Mo", "6 Mo"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc", "Percap Inc", "Emp"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Purpose Indicators", "No", "Yes", "No", "Yes", "No", "Yes"),
                           c("Cluster", "Purpose", "Purpose", "Purpose",  "Purpose", "Purpose", "Purpose")),
          out = paste0(tables_wd, '/Issuance Level Abnormal Counts Regs.tex')
)


reg1 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_unlim_bond_issuance ==1])
reg2 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg3 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_lim_bond_issuance ==1])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_lim_bond_issuance == 1])
reg5 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[rev_bond_issuance ==1])
reg6 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[rev_bond_issuance == 1])

stargazer(reg1, reg2, reg3, reg4,reg5, reg6,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Issuance Level Counts of Articles By Bond Type',
          column.labels = c("GO Unlim", "GO Unlim", "GO Lim", "GO Lim", "Rev", "Rev"),
          dep.var.caption = c("Counts of Articles:"),
          dep.var.labels = c("Issuance Mo", "6 Mo", "Issuance Mo", "6 Mo", "Issuance Mo", "6 Mo"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc", "Percap Inc", "Emp"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Purpose Indicators", "No", "Yes", "No", "Yes", "No", "Yes"),
                           c("Cluster", "Purpose", "Purpose", "Purpose",  "Purpose", "Purpose", "Purpose")),
          out = paste0(tables_wd, '/Issuance Level Counts Regs By Bond Type.tex')
)

reg1 <- felm(abnormal_rp_article_count_issuance_month ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_unlim_bond_issuance ==1])
reg2 <- felm(abnormal_rp_article_count_6mo ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg3 <- felm(abnormal_rp_article_count_issuance_month ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_lim_bond_issuance ==1])
reg4 <- felm(abnormal_rp_article_count_6mo ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_lim_bond_issuance == 1])
reg5 <- felm(abnormal_rp_article_count_issuance_month ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[rev_bond_issuance ==1])
reg6 <- felm(abnormal_rp_article_count_6mo ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[rev_bond_issuance == 1])

stargazer(reg1, reg2, reg3, reg4,reg5, reg6,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Issuance Level Abnormal Counts of Articles By Bond Type',
          column.labels = c("GO Unlim", "GO Unlim", "GO Lim", "GO Lim", "Rev", "Rev"),
          dep.var.caption = c("Abnormal Counts of Articles:"),
          dep.var.labels = c("Issuance Mo", "6 Mo", "Issuance Mo", "6 Mo", "Issuance Mo", "6 Mo"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc", "Percap Inc", "Emp"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Purpose Indicators", "No", "Yes", "No", "Yes", "No", "Yes"),
                           c("Cluster", "Purpose", "Purpose", "Purpose",  "Purpose", "Purpose", "Purpose")),
          out = paste0(tables_wd, '/Issuance Level Abnormal Counts Regs By Bond Type.tex')
)



reg1a <- felm(abnormal_rp_article_count ~ city_go_vote|year|0|use_proceeds, data = issuance_lvl[go_unlim == 1])
reg3a <- felm(abnormal_rp_article_count ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_unlim == 1])

reg1b <- felm(abnormal_rp_article_count ~ city_go_vote|year|0|0, data = issuance_lvl[go_lim == 1])
reg3b <- felm(abnormal_rp_article_count ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[go_lim == 1])

reg1c <- felm(abnormal_rp_article_count ~ city_go_vote|year|0|0, data = issuance_lvl[rev == 1])
reg3c <- felm(abnormal_rp_article_count ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + use_proceeds|0|use_proceeds, data = issuance_lvl[rev == 1])

stargazer(reg1, reg3, reg1a, reg3a, reg1b, reg3b, reg1c, reg3c, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Issuance-Level Regressions',
          dep.var.labels = c("Abnormal Articles"),
          column.labels = c("All Bonds", "Only GO Unlim", "Only GO Lim", 'Only Revenue'), 
          covariate.labels = c('I(Vote)', 'Amount', 'GDP', 'Pers Inc', 'Percap Inc', 'Employment'),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Purpose Indicators", "No", "Yes", "No", "Yes", "No", "Yes", "No", "Yes"),
                           c("Cluster", "Purpose", "Purpose", "Purpose",  "Purpose", "Purpose", "Purpose", "Purpose", "Purpose", "Purpose")),
          out = paste0(tables_wd, '/IssuanceLvl_Regressions.tex'))



#_______________ILLINOIS________________
ill_data = read_parquet(paste0(data_wd, '/IL_City_Month_Data_Headline_Filter.gzip'))
#ill_data = read_parquet(paste0(data_wd, '/Full_City_Month_Data_All_RP_Articles_Included.gzip'))
ill_data = as.data.table(ill_data)
ill_data = ill_data[!(seed_issuer_id) %in% c(7809, 2909)]
ill_data[, rp_article_count_raw := rp_article_count]
ill_data[, rp_article_count := log(1+rp_article_count)]
ill_data = ill_data[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
ill_data[, year_month := paste0(year, '_', month)]

reg1b <- felm(rp_article_count ~ bond_issuance_next_6mth + bond_issuance_next_6mth:homerule + bond_issuance_next_6mth:ln_bond_amount_current_month + homerule |year_month + seed_issuer_id|0|year_month + seed_issuer_id, data = ill_data)

reg1b <- felm(rp_article_count ~ bond_issuance_month + bond_issuance_month:homerule + bond_issuance_month:ln_bond_amount_current_month  + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |year_month|0|year_month + seed_issuer_id, data = ill_data)

issuance_lvl = fread(paste0(data_wd, '/IL_Issuance_Lvl_AbnormalNews_HeadlineFilter.csv'))

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
#issuance_lvl = issuance_lvl[!is.na(city_go_vote)]
issuance_lvl[, abnormal_rp_article_count_6mo := ifelse(is.infinite(abnormal_rp_article_count_6mo), NA, abnormal_rp_article_count_6mo)]
issuance_lvl[, abnormal_rp_article_count_issuance_month := ifelse(is.infinite(abnormal_rp_article_count_issuance_month), NA, abnormal_rp_article_count_issuance_month)]
issuance_lvl <- unique(ill_data[, .(seed_issuer_id, homerule, homerule_method, year)])[issuance_lvl, on = .(seed_issuer_id, year)]

reg1 <- felm(issuance_month_total_articles ~ homerule + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance ==1])
reg2 <- felm(total_rp_articles_6mo_window_event ~ homerule + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance == 1])

issuance_lvl[, mean_hr := mean(homerule), .(seed_issuer_id)]
switcher <- issuance_lvl[mean_hr != 0 & mean_hr != 1]
switcher[, home_rule_c := ifelse(homerule == 1 & homerule_method == 'C', 1, 0)]
switcher[, home_rule_r := ifelse(homerule == 1 & homerule_method == 'R', 1, 0)]

reg1 <- felm(issuance_month_total_articles ~ homerule + ln_amount + ln_amount:homerule + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + seed_issuer_id|0|0, data = switcher)
