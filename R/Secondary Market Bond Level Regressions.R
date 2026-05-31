'''
Secondary market yields tests at the BOND level
'''

#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_km_issuerlvl"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Bond_Level_Secondary_Market_Vars_With_Bond_Vars_2005_2023.csv')
data <- data[city == 1 & !is.na(city_go_vote) & !is.na(ln_pop) & city_rev_vote == 0 & go_unlim == 1]

data[, yrmonth := paste0(year, month)]
#data <- data[!is.na(markup_3yr) & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)]


col_list = c('yield_volatility_1yr', 'yield_volatility_6mo', 'yield_volatility_3yr', 
             'markup_1yr', 'markup_3yr', 'markup_6mo','markup_retail_1yr', 'markup_retail_3yr', 'markup_retail_6mo',
             'markup_small_retail_1yr', 'markup_small_retail_3yr', 'markup_small_retail_6mo'
)

Wins <- function(df, col_list){
  for (col in col_list){
    df[, (col) := Winsorize(df[[col]], val = quantile(df[[col]], probs = c(0.01, 0.99), na.rm = T))]
  }
  return(df)
}

data <- Wins(data, col_list)

#data <- Wins(data, col_list)

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data With MSRB 20250707.csv')
border_states <- border_states[go_unlim == 1 & category != 'green']
border_states <- Wins(border_states, col_list)
#border_states <- unique(border_states[, .(seed_issuer_id,group)])
#border_states <- data[border_states, on = .(seed_issuer_id)]
#---------------------------------------

mean(data$markup_institutional_3yr, na.rm = T)

data[, log_num_trades_1yr := log(number_of_trades_1yr)]
data[, log_num_trades_3yr := log(number_of_trades_3yr)]
data[, log_num_trades_6mo := log(number_of_trades_6mo)]
border_states[, log_num_trades_1yr := log(number_of_trades_1yr)]
border_states[, log_num_trades_3yr := log(number_of_trades_3yr)]
border_states[, log_num_trades_6mo := log(number_of_trades_6mo)]
border_states[, group_year := paste0(group, year)]

data[,markup_1yr := markup_1yr/100]
data[,markup_retail_1yr := markup_retail_1yr/100]
data[,markup_institutional_1yr := markup_institutional_1yr/100]

border_states[,markup_1yr := markup_1yr/100]
border_states[,markup_retail_1yr := markup_retail_1yr/100]
border_states[,markup_institutional_1yr := markup_institutional_1yr/100]


r1 <- felm(markup_1yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr |yrmonth + purp_broad|0|issue_id, data = data)
summary(r1)
r2 <- felm(markup_retail_1yr ~ city_go_vote + ln_amount + ln_maturity_mths+ callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr|yrmonth + purp_broad|0|issue_id, data = data)
summary(r2)
r3 <- felm(markup_institutional_1yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr |yrmonth + purp_broad|0|issue_id, data = data)
summary(r3)


r4 <- felm(markup_1yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr |group_year + purp_broad|0|issue_id, data = border_states)
summary(r4)
r5 <- felm(markup_retail_1yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr|group_year + purp_broad|0|issue_id, data = border_states)
summary(r5)
r6 <- felm(markup_institutional_1yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + glm_proactive + state_ltgo_allowed + state_go_vote + log_num_trades_1yr |group_year + purp_broad|0|issue_id, data = border_states)
summary(r6)


stargazer(r1, r2, r3, r4, r5, r6)
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
            title = 'Vote Requirements and Liquidity (Issuance Level)',
          dep.var.caption = "",
          dep.var.labels = c('Markup', 'Markup - Retail', 'Markup - Institutional'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "County ln(GDP)", "County ln(Pop)", "County ln(Pers. Inc)", "County ln(Emp)",
                               "Proactive State", "LTGO Allowed", "State GO Vote", "Number of Trades"),
          add.lines = list(c("Time FE", "YM", "YM", "YM", "Pair-Year", "Pair-Year", "Pair-Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue")),
          out = paste0(tables_wd, '/liquidity.tex'))

