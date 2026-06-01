library(stargazer)
library(data.table)
library(lfe)
library(ggplot2)
#library(arrow)
### Load data ####

desc_dir <- '~/Dropbox/Voting on Bonds/Descriptives/Full Sample/'
overleaf_plots <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Proposal: Voting on bonds/figures'
overleaf_tables <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Proposal: Voting on bonds/tables/2411_fullsample/'

dta <- fread('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/241120_issue_level.csv')

# check for seed issuers in multiple states 
dta[, num_states := uniqueN(state), .(seed_issuer)]
uniqueN(dta[num_states > 1]$seed_issuer) # 3 issuers with problems 
dta <- dta[num_states == 1]

dta[, callable_ind := ifelse(wavg_callable > 0, 1, 0)]
dta[, sinkable_ind := ifelse(wavg_sinkable > 0, 1, 0)]
dta[, insured_ind := ifelse(wavg_insured > 0, 1, 0)]

### Drop missing values for necessary variables ####

# List of columns to check for NA values
cols_to_check <- c("wavg_offering_yield", "vote_req", "log_wavg_maturity", "log_issue_size", "ln_num_cusip", 
                   "callable_ind", "sinkable_ind", "rated_dummy", "pop", "gdp", 
                   "pers_inc", 'insured_ind')

for (col in cols_to_check){
  dta <- dta[!is.na(get(col))]
}


### Filter to City GO observations ####

# filter to city and go
city_go <- dta[city == 1 & rev == 0]
# only include states with vote requirement data available
city_go <- city_go[!is.na(city_go_vote)]

### Variable adjustments ####

# pull offering month 
city_go[, offering_date := as.Date(offering_date, format = '%d%b%Y')]
city_go[, month := format(offering_date, '%m')]
# log-adjust demo data
city_go[, pop := log(pop)]
city_go[, gdp := log(gdp)]
city_go[, pers_inc := log(pers_inc)]

# trim offering yield 
city_go[, wavg_offering_yield_trim := wavg_offering_yield]
city_go[, wavg_offering_yield_trim := ifelse(wavg_offering_yield >= quantile(wavg_offering_yield, 0.99), NA, wavg_offering_yield_trim)]
city_go[, wavg_offering_yield_trim := ifelse(wavg_offering_yield <= quantile(wavg_offering_yield, 0.01), NA, wavg_offering_yield_trim)]

### Descriptives ####

for_desc <- city_go[, .(wavg_offering_yield, wavg_offering_yield_trim, yield_volatility, 
                        markup, 
                        markup_retail,
                        markup_inst,  
                        vote_req, log_wavg_maturity, log_issue_size, callable_ind, 
                        sinkable_ind, insured_ind, rated_dummy)]

stargazer(for_desc, type = "latex", median = T, min.max = T, iqr = T, no.space = TRUE,
          covariate.labels = c("Yield (raw)", "Yield (trim)", "Yield vol", 
                               "Markup", "Markup (retail)", "Markup (inst)", 
                               "Vote (I)", "log(Maturity)", "log(Size)", "Callable (I)", 
                               "Sinkable (I)", "Insured (I)", "Rated (I)"
                               ),
          title = 'Summary Statistics (City GO)', out = paste0(overleaf_tables, '241125_City_GO_Descriptives.tex'))

### write function
regs <- function(var, var_name, title, out_file){
  
  reg1 <- felm(get(var) ~ vote_req|0|0|0, data = city_go) # in stargazer, specify robust standard errors 
  reg2 <- felm(get(var) ~ vote_req|year + month|0|state, data = city_go)
  #reg3 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy|year + month|0|state, data = city_go)
  reg3 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + wavg_callable + wavg_sinkable + wavg_insured + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go)
  reg4 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go)
  
  stargazer(reg1, reg2, reg3, reg4, 
            se = list(reg1$rse, reg2$cse, reg3$cse, reg4$cse), 
            type = 'latex', report = 'vc*t',no.space = TRUE,
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            title = title,
           
           # covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)", "Callable (I)", "Sinkable (I)", "Insured (I)", 
            #                     "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)","Callable", "Sinkable", "Insured", 
                                 "Callable (I)", "Sinkable (I)", "Insured (I)",
                                 "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            add.lines = list(c("Year", "No", "Yes", "Yes", "Yes"),
                             c("Month", "No", "Yes", "Yes", "Yes"),
                             c("SE", "Robust", "State", "State", "State", "State"))
            )
}

# offering yield
out_dir = paste0(overleaf_tables,'241125_city_go_off_yield.tex')
regs('wavg_offering_yield', 'Yield (raw)', 'Vote Requirement and Offering Yield', out_dir)

# offering yield trim 
out_dir = paste0(overleaf_tables,'241125_city_go_off_yield_trim.tex')
regs('wavg_offering_yield_trim', 'Yield (trim)','Vote Requirement and Offering Yield (Trim)',out_dir)

# yield volatility
out_dir = paste0(overleaf_tables,'241125_city_go_yield_vol.tex')
regs('yield_volatility', 'Yield Vol', 'Vote Requirement and Yield Volatility', out_dir)

# markup
out_dir = paste0(overleaf_tables,'241125_city_go_markup.tex')
regs('markup', 'Markup', 'Vote Requirement and Markup', out_dir)


# markup retail
out_dir = paste0(overleaf_tables,'241125_city_go_markup_retail.tex')
regs('markup_retail', 'Markup (retail)', 'Vote Requirement and Markup - Retail', out_dir)


# markup inst
out_dir = paste0(overleaf_tables,'241125_city_go_markup_inst.tex')
regs('markup_inst', 'Markup (inst)', 'Vote Requirement and Markup - Institutional', out_dir)
##########################################################################################################################################
# some subsamples
##########################################################################################################################################


regs <- function(var, var_name, title, out_file){
  
  reg1 <- felm(get(var) ~ vote_req|0|0|0, data = city_go[!(state %in% c('MA', 'IA'))]) # in stargazer, specify robust standard errors 
  reg2 <- felm(get(var) ~ vote_req|year + month|0|state, data = city_go[!(state %in% c('MA', 'IA'))])
  #reg3 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy|year + month|0|state, data = city_go)
  reg3 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + wavg_callable + wavg_sinkable + wavg_insured + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go[!(state %in% c('MA', 'IA'))])
  reg4 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go[!(state %in% c('MA', 'IA'))])
  
  stargazer(reg1, reg2, reg3, reg4, 
            se = list(reg1$rse, reg2$cse, reg3$cse, reg4$cse), 
            type = 'latex', report = 'vc*t',no.space = TRUE,
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            title = title,
            
            # covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)", "Callable (I)", "Sinkable (I)", "Insured (I)", 
            #                     "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)","Callable", "Sinkable", "Insured", 
                                 "Callable (I)", "Sinkable (I)", "Insured (I)",
                                 "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            add.lines = list(c("Year", "No", "Yes", "Yes", "Yes"),
                             c("Month", "No", "Yes", "Yes", "Yes"),
                             c("SE", "Robust", "State", "State", "State", "State"))
  )
}

# offering yield
out_dir = paste0(overleaf_tables,'241125_city_go_off_yield.tex')
regs('wavg_offering_yield', 'Yield (raw)', 'Vote Requirement and Offering Yield (MA and IA Removed)', out_dir)

# offering yield trim 
out_dir = paste0(overleaf_tables,'241125_city_go_off_yield_trim.tex')
regs('wavg_offering_yield_trim', 'Yield (trim)','Vote Requirement and Offering Yield (Trim) (MA and IA Removed)',out_dir)

# small and large
issuer_avg_pop = city_go[, list(avg_pop = mean(pop)), .(seed_issuer)]
issuer_avg_pop[, HighPop := ifelse(avg_pop > median(avg_pop), 1, 0)]
city_go <- issuer_avg_pop[city_go, on = .(seed_issuer)]

regs <- function(var, var_name, title, out_file){
  
  reg1 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go[HighPop == 1])
  reg2 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_go[HighPop == 0])
  stargazer(reg1, reg2, 
            type = 'latex', report = 'vc*t',no.space = TRUE,
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            title = title,
            column.labels = c("High Population Issuers", "Low Population Issuers"),
            # covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)", "Callable (I)", "Sinkable (I)", "Insured (I)", 
            #                     "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)","Callable", "Sinkable", "Insured", 
                                 "Callable (I)", "Sinkable (I)", "Insured (I)",
                                 "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            add.lines = list(c("Year", "Yes", "Yes"),
                             c("Month", "Yes", "Yes"),
                             c("SE", "State", "State"))
  )
}

# offering yield
out_dir = paste0(overleaf_tables,'241206_city_go_off_yield_popsplit.tex')
regs('wavg_offering_yield', 'Yield (raw)', 'Vote Requirement and Offering Yield (Population Split)', out_dir)

# offering yield trim 
out_dir = paste0(overleaf_tables,'2241206_city_go_off_yield_trim_popsplit.tex')
regs('wavg_offering_yield_trim', 'Yield (trim)','Vote Requirement and Offering Yield (Trim) (Population Split)',out_dir)

rm(city_go)
##########################################################################################################################################
# Combine GO and revenue bonds into one regression 
##########################################################################################################################################

### Filter to City Rev observations ####

# filter to city and go
city<- dta[city == 1]
city[, go := ifelse(rev == 1, 0, 1)]
# only include states with vote requirement data available
city <- city[!is.na(city_go_vote) & !is.na(city_rev_vote)]
city <- city[city_rev_vote == 0]

### Variable adjustments ####

# pull offering month 
city[, offering_date := as.Date(offering_date, format = '%d%b%Y')]
city[, month := format(offering_date, '%m')]
# log-adjust demo data
city[, pop := log(pop)]
city[, gdp := log(gdp)]
city[, pers_inc := log(pers_inc)]

# trim offering yield 
city[, wavg_offering_yield_trim := wavg_offering_yield]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield >= quantile(wavg_offering_yield, 0.99), NA, wavg_offering_yield_trim)]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield <= quantile(wavg_offering_yield, 0.01), NA, wavg_offering_yield_trim)]



### Descriptives ####

# update vote_req variable 
city[, vote_req := ifelse(city_go_vote == 1, 1, 0)]

for_desc <- city[, .(wavg_offering_yield, wavg_offering_yield_trim, yield_volatility, 
                        markup, 
                        markup_retail,
                        markup_inst,  
                        vote_req, go, log_wavg_maturity, log_issue_size, callable_ind, 
                        sinkable_ind, insured_ind, rated_dummy)]

stargazer(for_desc, type = "latex", median = T, min.max = T, iqr = T, no.space = TRUE,
          covariate.labels = c("Yield (raw)", "Yield (trim)", "Yield vol", 
                               "Markup", "Markup (retail)", "Markup (inst)", 
                               "Vote (I)", "GO (I)", "log(Maturity)", "log(Size)", "Callable (I)", 
                               "Sinkable (I)", "Insured (I)", "Rated (I)"
          ),
          title = 'Summary Statistics (City Revenue)', out = '~/Dropbox/Voting on Bonds/Descriptives/Full Sample/241125_City_Rev_and_Go_Descriptives.tex')

### write function for regression analysis ####

regs <- function(var, var_name, title, out_file){
  
  reg1 <- felm(get(var) ~ vote_req + go + vote_req:go|0|0|0, data = city) # in stargazer, specify robust standard errors 
  reg2 <- felm(get(var) ~ vote_req + go + vote_req:go|year + month|0|state, data = city)
  reg3 <- felm(get(var) ~ vote_req + go + vote_req:go|seed_issuer + year + month|0|state, data = city)
  reg4 <- felm(get(var)~ vote_req + go + vote_req:go + log_issue_size + log_wavg_maturity + wavg_callable + wavg_sinkable + wavg_insured + rated_dummy + pop + gdp + pers_inc|seed_issuer + year + month|0|state, data = city)
  reg5 <- felm(get(var)~ vote_req + go + vote_req:go + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|seed_issuer + year + month|0|state, data = city)
  
  stargazer(reg1, reg2, reg3, reg4,reg5, 
            se = list(reg1$rse, reg2$cse, reg3$cse, reg4$cse, reg5$cse), 
            type = 'latex', report = 'vc*st',no.space = TRUE,
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            title = title,
            order = c(1, 2, 15, 3, 4, 5, 6, 7, 8, 9, 10, 11,12, 13, 14, 16),
            covariate.labels = c("Vote (I)", "GO (I)", "Vote (I) * GO (I)", "log(Size)", "log(Maturity)", 'Callable', 'Sinkable', 'Insured',
                                 "Callable (I)", "Sinkable (I)", "Insured (I)", 
                                 "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            add.lines = list(c("Year", "No", "Yes", "Yes", "Yes", "Yes"),
                             c("Month", "No", "Yes", "Yes", "Yes", "Yes"),
                             c("Issuer", "No", "No", "Yes", "Yes", "Yes"),
                             c("SE", "Robust", "State", "State", "State", "State"))
  )
}

# offering yield
out_dir = paste0(overleaf_tables,'241125_city_combined_off_yield.tex')
regs('wavg_offering_yield', 'Yield (raw)', 'Vote Requirement and Offering Yield', out_dir)

# offering yield trim 
out_dir = paste0(overleaf_tables,'241125_city_combined_off_yield_trim.tex')
regs('wavg_offering_yield_trim', 'Yield (trim)','Vote Requirement and Offering Yield (Trim)',out_dir)

# yield volatility
out_dir = paste0(overleaf_tables,'241125_city_combined_yield_vol.tex')
regs('yield_volatility', 'Yield Vol', 'Vote Requirement and Yield Volatility', out_dir)

# markup
out_dir = paste0(overleaf_tables,'241125_city_combined_markup.tex')
regs('markup', 'Markup', 'Vote Requirement and Markup', out_dir)


# markup retail
out_dir = paste0(overleaf_tables,'241125_city_combined_markup_retail.tex')
regs('markup_retail', 'Markup (retail)', 'Vote Requirement and Markup - Retail', out_dir)


# markup inst
out_dir = paste0(overleaf_tables,'241125_city_combined_markup_inst.tex')
regs('markup_inst', 'Markup (inst)', 'Vote Requirement and Markup - Institutional', out_dir)


##########################################################################################################################################
# state level descriptives - how does difference in revenue and GO vary across states 
##########################################################################################################################################
state_agg <- city[, list(vote_req = vote_req[1], 
                         num_go = sum(go),
                         num_rev = sum(rev), 
                         go_offering_yield = mean(wavg_offering_yield[go == 1]), 
                         rev_offering_yield = mean(wavg_offering_yield[rev == 1])), .(state)]

state_agg <- state_agg[!is.na(go_offering_yield) & !is.na(rev_offering_yield)]

state_agg[, rev_minus_go := rev_offering_yield - go_offering_yield]

plot_go = ggplot() + 
  geom_boxplot(data = state_agg[vote_req == 1], aes (x = "GO Vote Required", y = go_offering_yield)) + 
  geom_boxplot(data = state_agg[vote_req == 0], aes(x = "No GO Vote Required", y = go_offering_yield)) + 
  labs(title = "Box and Whisker Plot of State-Level Mean GO Bond Yield", 
       x = 'Vote Requirement', y = 'GO Yield') + 
  theme_bw()

p_name = paste0(overleaf_plots,'/BW Mean GO Yield by Vote Req.png')
ggsave(p_name, plot_go, width = 8, height = 5)


plot_rev = ggplot() + 
  geom_boxplot(data = state_agg[vote_req == 1], aes (x = "GO Vote Required", y = rev_offering_yield)) + 
  geom_boxplot(data = state_agg[vote_req == 0], aes(x = "No GO Vote Required", y = rev_offering_yield)) + 
  labs(title = "Box and Whisker Plot of State-Level Mean Revenue Bond Yield", 
       x = 'Vote Requirement', y = 'Revenue Yield') + 
  theme_bw()

p_name = paste0(overleaf_plots,'/BW Mean Rev Yield by Vote Req.png')
ggsave(p_name, plot_rev, width = 8, height = 5)

plot_difference = ggplot() + 
  geom_boxplot(data = state_agg[vote_req == 1], aes (x = "GO Vote Required", y = rev_minus_go)) + 
  geom_boxplot(data = state_agg[vote_req == 0], aes(x = "No GO Vote Required", y = rev_minus_go)) + 
  labs(title = "Box and Whisker Plot of State-Level Difference in Mean Revenue Bond Yield - Mean GO Bond Yield", 
       x = 'Vote Requirement', y = 'Revenue Yield - GO Yield') + 
  theme_bw()

p_name = paste0(overleaf_plots,'/BW Mean Rev Yield Minus GO Yield by Vote Req.png')
ggsave(p_name, plot_difference, width = 8, height = 5)


#################################### 
# now run main regression by state and plot the coefficient of interest by vote requirement 

states <- unique(city[, .(state, city_go_vote)])

reg_coef = data.table()
for (i in 1:nrow(states)){
  print(i)
  st = states[i, 'state']$state
  vote_req = states[i, 'city_go_vote']$city_go_vote
  if (mean(city[state == st]$go) %in% c(0, 1)){
    next
  }
  by_year = city[state == st, list(mean_go = mean(go)), .(year)]
  if (all(by_year$mean_go %in% c(0, 1))){
    next
  }
  
  by_issuer = city[state == st, list(mean_go = mean(go)), .(seed_issuer)]
  if (all(by_issuer$mean_go %in% c(0, 1))){
    next
  }
  
  reg <- felm(wavg_offering_yield_trim~ go + log_issue_size + 
                log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + 
                rated_dummy + pop + gdp + pers_inc|year + month|0|0, data = city[state == st])
  coef = reg$coefficients[1]
  print(coef)
  
  row = as.data.table(c(st, vote_req, coef))
  row = t(row)
  reg_coef = rbind(reg_coef, row)
}

colnames(reg_coef) <- c('state', 'vote_req', 'coefficient')
reg_coef[, coefficient := as.numeric(coefficient)]
reg_coef <- reg_coef[!is.na(coefficient)]

reg_coef <- reg_coef[order(vote_req, coefficient)]

state_counts = city[, list(GOBonds = sum(go), RevBonds = sum(rev)), .(state)]

reg_coef <- state_counts[reg_coef, on = .(state)]
reg_coef <- reg_coef[, .(state, vote_req, coefficient, GOBonds, RevBonds)]
colnames(reg_coef) <- c('State', 'GO Vote', 'Coefficient', 'Num GO', 'Num Revenue')

stargazer(reg_coef, type = 'latex', summary = F, rownames = F, no.space = T, 
          out = paste0(overleaf_tables, '/State Level Coefficients.tex'))


plot_coef = ggplot() + 
  geom_boxplot(data = reg_coef[vote_req == 1], aes (x = "GO Vote Required", y = coefficient)) + 
  geom_boxplot(data = reg_coef[vote_req == 0], aes(x = "No GO Vote Required", y = coefficient)) + 
  labs(title = "Box and Whisker Plot of State-Level GO Coeffficient", 
       x = 'Vote Requirement', y = 'Coefficient') + 
  theme_bw()

p_name = paste0(overleaf_plots,'/BW State Level GO Coefficient by Vote Req.png')
ggsave(p_name, plot_coef, width = 8, height = 5)

#################################### 
# differences in issuance characteristics across vote requiring non-requiring 

# filter to city and go
city<- dta[city == 1 & rev == 0]
# only include states with vote requirement data available
city <- city[!is.na(city_go_vote)]

### Variable adjustments ####

# pull offering month 
city[, offering_date := as.Date(offering_date, format = '%d%b%Y')]
city[, month := format(offering_date, '%m')]
# log-adjust demo data
city[, pop := log(pop)]
city[, gdp := log(gdp)]
city[, pers_inc := log(pers_inc)]

# trim offering yield 
city[, wavg_offering_yield_trim := wavg_offering_yield]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield >= quantile(wavg_offering_yield, 0.99), NA, wavg_offering_yield_trim)]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield <= quantile(wavg_offering_yield, 0.01), NA, wavg_offering_yield_trim)]


vars = c('wavg_offering_yield', 'log_issue_size', 'log_wavg_maturity',
         'wavg_callable', 'callable_ind', 'wavg_sinkable', 'sinkable_ind', 
          'wavg_insured', 'insured_ind', 'rated_dummy', 'pop', 'gdp', 'pers_inc')

differences <- data.table(variable = character(),
                          mean_vote_req_1 = numeric(), count_vote_req_1 = integer(),
                          mean_vote_req_0 = numeric(), count_vote_req_0 = integer(),
                          difference = numeric(),
                          t_stat = numeric())

for (var in vars){
  
  # Calculate mean values and counts for each variable based on vote_req
  mean_vote_req_0 <- mean(city[city_go_vote == 0, get(var)], na.rm = TRUE)
  mean_vote_req_1 <- mean(city[city_go_vote == 1, get(var)], na.rm = TRUE)
  
  count_vote_req_0 <- nrow(city[city_go_vote == 0 & !is.na(get(var))])
  count_vote_req_1 <- nrow(city[city_go_vote == 1 & !is.na(get(var))])
  
  # Perform t-test
  t_test_result <- t.test(city[vote_req == 1, get(var)],
                          city[vote_req == 0, get(var)],
                          na.action = na.omit)
  
  # Store the results in the differences data table
  differences <- rbind(differences, data.table(variable = var,
                                               mean_vote_req_1 = mean_vote_req_1,
                                               count_vote_req_1 = count_vote_req_1,
                                               mean_vote_req_0 = mean_vote_req_0,
                                               count_vote_req_0 = count_vote_req_0,
                                               difference = mean_vote_req_1 - mean_vote_req_0,
                                               t_stat = t_test_result$statistic))
  
}

differences[, variable := c('Yield (raw)', 'log(Size)', 'log(Maturity)', 
                            'Callable', 'Callable (I)', 
                            'Sinkable', 'Sinkable (I)', 
                            'Insured', 'Insured (I)', 
                            'Rated (I)', 'log(Pop)', 'log(GDP)', 'log(Inc)')]
colnames(differences) <- c(
  'Variable', 
  'Mean (Vote = 1)', 
  'Count (Vote = 1)', 
  'Mean (Vote = 0)', 
  'Count (Vote = 0)', 
  'Difference', 
  't-stat'
)

stargazer(differences, summary = F, type = "latex",
          rownames = F,  no.space = TRUE,column.sep.width = "-10pt", title = 'Means by Vote GO Vote Requirement',
          out = paste0(overleaf_tables, '241202_city_go_desc_by_vote.tex') )



# differences in issuance characteristics across vote requiring non-requiring REVENUE

# filter to city and go
city<- dta[city == 1 & rev == 1]
# only include states with vote requirement data available
city <- city[!is.na(city_go_vote)]

### Variable adjustments ####

# pull offering month 
city[, offering_date := as.Date(offering_date, format = '%d%b%Y')]
city[, month := format(offering_date, '%m')]
# log-adjust demo data
city[, pop := log(pop)]
city[, gdp := log(gdp)]
city[, pers_inc := log(pers_inc)]

# trim offering yield 
city[, wavg_offering_yield_trim := wavg_offering_yield]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield >= quantile(wavg_offering_yield, 0.99), NA, wavg_offering_yield_trim)]
city[, wavg_offering_yield_trim := ifelse(wavg_offering_yield <= quantile(wavg_offering_yield, 0.01), NA, wavg_offering_yield_trim)]


vars = c('wavg_offering_yield', 'log_issue_size', 'log_wavg_maturity',
         'wavg_callable', 'callable_ind', 'wavg_sinkable', 'sinkable_ind', 
         'wavg_insured', 'insured_ind', 'rated_dummy', 'pop', 'gdp', 'pers_inc')

differences <- data.table(variable = character(),
                          mean_vote_req_1 = numeric(), count_vote_req_1 = integer(),
                          mean_vote_req_0 = numeric(), count_vote_req_0 = integer(),
                          difference = numeric(),
                          t_stat = numeric())

for (var in vars){
  
  # Calculate mean values and counts for each variable based on vote_req
  mean_vote_req_0 <- mean(city[city_go_vote == 0, get(var)], na.rm = TRUE)
  mean_vote_req_1 <- mean(city[city_go_vote == 1, get(var)], na.rm = TRUE)
  
  count_vote_req_0 <- nrow(city[city_go_vote == 0 & !is.na(get(var))])
  count_vote_req_1 <- nrow(city[city_go_vote == 1 & !is.na(get(var))])
  
  # Perform t-test
  t_test_result <- t.test(city[city_go_vote == 1, get(var)],
                          city[city_go_vote == 0, get(var)],
                          na.action = na.omit)
  
  # Store the results in the differences data table
  differences <- rbind(differences, data.table(variable = var,
                                               mean_vote_req_1 = mean_vote_req_1,
                                               count_vote_req_1 = count_vote_req_1,
                                               mean_vote_req_0 = mean_vote_req_0,
                                               count_vote_req_0 = count_vote_req_0,
                                               difference = mean_vote_req_1 - mean_vote_req_0,
                                               t_stat = t_test_result$statistic))
  
}

differences[, variable := c('Yield (raw', 'log(Size)', 'log(Maturity)', 
                            'Callable', 'Callable (I)', 
                            'Sinkable', 'Sinkable (I)', 
                            'Insured', 'Insured (I)', 
                            'Rated (I)', 'log(Pop)', 'log(GDP)', 'log(Inc)')]
colnames(differences) <- c(
  'Variable', 
  'Mean (Vote = 1)', 
  'Count (Vote = 1)', 
  'Mean (Vote = 0)', 
  'Count (Vote = 0)', 
  'Difference', 
  't-stat'
)

stargazer(differences, summary = F, type = "latex",
          rownames = F,  no.space = TRUE,column.sep.width = "-10pt", title = 'Means by Vote GO Vote Requirement',
          out = paste0(overleaf_tables, '241202_city_rev_desc_by_vote.tex') )


##########################################################################################################################################
# Revenue bonds in cities with no vote, but use go vote indicator as placebo 
##########################################################################################################################################


### Filter to City observations ####

# filter to city and go
city_rev <- dta[city == 1 & rev == 1]
# only include states with vote requirement data available
city_rev <- city_rev[!is.na(city_go_vote) & !is.na(city_rev_vote)]
city_rev <- city_rev[city_rev_vote == 0]

### Variable adjustments ####

# pull offering month 
city_rev[, offering_date := as.Date(offering_date, format = '%d%b%Y')]
city_rev[, month := format(offering_date, '%m')]
# log-adjust demo data
city_rev[, pop := log(pop)]
city_rev[, gdp := log(gdp)]
city_rev[, pers_inc := log(pers_inc)]

# trim offering yield 
city_rev[, wavg_offering_yield_trim := wavg_offering_yield]
city_rev[, wavg_offering_yield_trim := ifelse(wavg_offering_yield >= quantile(wavg_offering_yield, 0.99), NA, wavg_offering_yield_trim)]
city_rev[, wavg_offering_yield_trim := ifelse(wavg_offering_yield <= quantile(wavg_offering_yield, 0.01), NA, wavg_offering_yield_trim)]



### Descriptives ####

# update vote_req variable 
city_rev[, vote_req := ifelse(city_go_vote == 1, 1, 0)]

for_desc <- city_rev[, .(wavg_offering_yield, wavg_offering_yield_trim, yield_volatility, 
                         markup, 
                         markup_retail,
                         markup_inst,  
                         vote_req, log_wavg_maturity, log_issue_size, callable_ind, 
                         sinkable_ind, insured_ind, rated_dummy)]

stargazer(for_desc, type = "latex", median = T, min.max = T, iqr = T, no.space = TRUE,
          covariate.labels = c("Yield (raw)", "Yield (trim)", "Yield vol", 
                               "Markup", "Markup (retail)", "Markup (inst)", 
                               "Vote (I)", "log(Maturity)", "log(Size)", "Callable (I)", 
                               "Sinkable (I)", "Insured (I)", "Rated (I)"
          ),
          title = 'Summary Statistics (City Revenue)', out = '~/Dropbox/Voting on Bonds/Descriptives/Full Sample/241125_City_Rev_Descriptives.tex')

### write function for regression analysis ####

regs <- function(var, var_name, title, out_file){
  
  reg1 <- felm(get(var) ~ vote_req|0|0|0, data = city_rev) # in stargazer, specify robust standard errors 
  reg2 <- felm(get(var) ~ vote_req|year + month|0|state, data = city_rev)
  reg3 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + wavg_callable + wavg_sinkable + wavg_insured + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_rev)
  reg4 <- felm(get(var)~ vote_req + log_issue_size + log_wavg_maturity + callable_ind + sinkable_ind + insured_ind + rated_dummy + pop + gdp + pers_inc|year + month|0|state, data = city_rev)
  
  stargazer(reg1, reg2, reg3, reg4, 
            se = list(reg1$rse, reg2$cse, reg3$cse, reg4$cse), 
            type = 'latex', report = 'vc*t',no.space = TRUE,
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            title = title,
            covariate.labels = c("Vote (I)", "log(Size)", "log(Maturity)", "Callable", "Sinkable", "Insured",
                                 "Callable (I)", "Sinkable (I)", "Insured (I)",
                                 "Rated (I)", "log(Pop)", "log(GDP)", "log(Inc)"),
            add.lines = list(c("Year", "No", "Yes", "Yes", "Yes"),
                             c("Month", "No", "Yes", "Yes", "Yes"),
                             c("SE", "Robust", "State", "State", "State", "State"))
  )
}

# offering yield
out_dir = paste0(overleaf_tables,'241125_city_rev_off_yield.tex')
regs('wavg_offering_yield', 'Yield (raw)', 'Vote Requirement and Offering Yield', out_dir)

# offering yield trim 
out_dir = paste0(overleaf_tables,'241125_city_rev_off_yield_trim.tex')
regs('wavg_offering_yield_trim', 'Yield (trim)','Vote Requirement and Offering Yield (Trim)',out_dir)

# yield volatility
out_dir = paste0(overleaf_tables,'241125_city_rev_yield_vol.tex')
regs('yield_volatility', 'Yield Vol', 'Vote Requirement and Yield Volatility', out_dir)

# markup
out_dir = paste0(overleaf_tables,'241125_city_rev_markup.tex')
regs('markup', 'Markup', 'Vote Requirement and Markup', out_dir)


# markup retail
out_dir = paste0(overleaf_tables,'241125_city_rev_markup_retail.tex')
regs('markup_retail', 'Markup (retail)', 'Vote Requirement and Markup - Retail', out_dir)


# markup inst
out_dir = paste0(overleaf_tables,'241125_city_rev_markup_inst.tex')
regs('markup_inst', 'Markup (inst)', 'Vote Requirement and Markup - Institutional', out_dir)


rm(city_rev)

##########################################################################################################################################
# Full Sample Descriptives - Breakdown of Revenue/GO bond 
##########################################################################################################################################

dta[, go := ifelse(rev == 0, 1, 0)]
city <- dta[city == 1]
city_no_rev <- city[city_rev_vote == 0 & !is.na(city_go_vote)]
city_no_rev <- city_no_rev[, list(Fraction_GO = mean(go)), .(city_go_vote)]
colnames(city_no_rev) <- c('GO Vote Required', 'Fraction GO Bonds')

county <- dta[county == 1]
county_no_rev <- county[county_rev_vote == 0 & !is.na(county_go_vote)]
county_no_rev <- county_no_rev[, list(Fraction_GO = mean(go)), .(county_go_vote)]
colnames(county_no_rev) <- c('GO Vote Required', 'Fraction GO Bonds')

stargazer(city_no_rev, summary = F, type = 'latex', no.space = TRUE, rownames = F,
          out = paste0(desc_dir, '241125_city_go_fraction_by_go_req.tex'), 
          title = "City Fraction of GO Bonds by GO Bond Vote Requirement")


stargazer(county_no_rev, summary = F, type = 'latex', no.space = TRUE, rownames = F,
          out = paste0(desc_dir, '241125_county_go_fraction_by_go_req.tex'), 
          title = "County Fraction of GO Bonds by GO Bond Vote Requirement")









##########################################################################################################################################
# now, secondary market tests 
##########################################################################################################################################
desc_dir <- '~/Dropbox/Voting on Bonds/Descriptives/MSRB/'
dta <- read_parquet('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Quarterly Liquidity by Recent Issuance_2005_2023.gzip')
dta <- as.data.table(dta)
dta <- dta[seed_issuer != 'MC MINN']

### Drop missing values for necessary variables ####

# List of columns to check for NA values
cols_to_check <- c("log_wavg_maturity", "log_issue_size", "ln_num_cusip", "city_go_vote",
                   "callable_ind", "sinkable_ind", "rated_dummy", "pop", "gdp", 
                   "pers_inc")

for (col in cols_to_check){
  dta <- dta[!is.na(get(col))]
}

# log-adjust demo data
dta[, pop := log(pop)]
dta[, gdp := log(gdp)]
dta[, pers_inc := log(pers_inc)]

### Descriptives ####

for_desc <- dta[, .(markup, markup_retail, markup_small_retail, markup_large_retail, 
                        markup_institutional, markup_small_institutional, markup_large_institutional, recent_issuance, city_go_vote,
                    year_since_issuance,
                        log_wavg_maturity, log_issue_size, ln_num_cusip, callable_ind, 
                        sinkable_ind, insured_ind, rated_dummy, pop, gdp, pers_inc)]

stargazer(for_desc, type = "latex", median = T, min.max = T, iqr = T, no.space = TRUE, out = '~/Dropbox/Voting on Bonds/Descriptives/MSRB/241125_City_GO_Descriptives.tex')

### write function for regression analysis ####

dta[, issuer := paste0(seed_issuer, '_', state)]

regs <- function(data, var, var_name, out_file){
  
  reg1 <- felm(get(var) ~ recent_issuance + city_go_vote + recent_issuance:city_go_vote|0|0|0, data = data) # in stargazer, specify robust standard errors 
  reg2 <- felm(get(var) ~ recent_issuance + city_go_vote + recent_issuance:city_go_vote|qtr|0|state, data = data)
  reg3 <- felm(get(var) ~ recent_issuance + recent_issuance:city_go_vote|qtr + seed_issuer|0|state, data = data)
  reg4 <- felm(get(var) ~ recent_issuance + recent_issuance:city_go_vote + year_since_issuance + log_issue_size + log_wavg_maturity + ln_num_cusip + callable_ind + insured_ind +  sinkable_ind + rated_dummy|qtr + seed_issuer|0|state, data = data)
  reg5 <- felm(get(var) ~ recent_issuance + recent_issuance:city_go_vote + year_since_issuance + log_issue_size + log_wavg_maturity + ln_num_cusip + callable_ind + insured_ind + sinkable_ind + rated_dummy + pop + gdp + pers_inc |qtr + seed_issuer|0|state, data = data)
  
  stargazer(reg1, reg2, reg3, reg4, reg5,
            se = list(reg1$rse, reg2$cse, reg3$cse, reg4$cse, reg5$cse), 
            type = 'latex', report = 'vc*t',
            omit.stat = c('ser'),
            dep.var.labels = c(var_name),
            out = out_file,
            order = c(1, 2, 14, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15),
            add.lines = list(c("FE", "None", "Year-Qtr", "Year-Qtr and Issuer", "Year-Qtr and Issuer", "Year-Qtr and Issuer", "Year-Qtr and Issuer"),
                             c("SE", "Robust", "State Cluster", "State Cluster", "State Cluster", "State Cluster"))
  )
}

out_dir = paste0(desc_dir,'241125_city_go_markup.txt')
regs(data = dta[number_of_trades> 1], var = 'markup', var_name = 'Markup', out_file = out_dir)

out_dir = paste0(desc_dir,'241125_city_go_markup_retail.txt')
regs(data =  dta[number_of_retail_trades> 1], var = 'markup_retail', var_name = 'Markup - Retail', out_file = out_dir)

out_dir = paste0(desc_dir,'241125_city_go_markup_institutional.txt')
regs(data =  dta[number_of_institutional_trades > 1], var = 'markup_institutional', var_name = 'Markup - Institutional', out_file = out_dir)
