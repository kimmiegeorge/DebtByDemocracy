
#trace(stargazer:::.stargazer.wrap, edit = T) # 950 change round to 2 digits
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_websites"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_250917.csv')
data <- data[total_subs > 1]

#data <- data[!(group %in% c('Tennessee/Arkansas', 'Arkansas/Mississippi'))]

# number issuers  112
#---------------------------------------

desc <- data[, .(debt_count, 
                 all_finance_count,
                         percent_debt_url, ln_cum_num_issues)]

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
          rownames = F, table.placement = "H", out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/Website Descriptives.tex')



#---------------------------------
# now just control 

data[, ln_cum_num_issues_all := log(1+cum_num_issues_all)]
data[, group := as.factor(group)]
data[, year := as.factor(year)]
# ROBUST
r1 <- fixest::fepois(debt_count ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = data, cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = data, cluster ~ fips)
r3 <- fixest::fepois(bond_or_debt_url ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = data, cluster ~ fips)

etable(r1, r2, r3, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       fontsize = 'small',
       dict = c(debt_count ='Debt Count',
                bond_count ='Bond Count',
                bond_or_debt_url = 'Bond or Debt URL Count',
                city_go_vote = 'Vote',
                ln_cum_num_issues_all = 'Num Issuances',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                year = 'Year'),
       placement = 'H',
       file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
       replace = TRUE)



