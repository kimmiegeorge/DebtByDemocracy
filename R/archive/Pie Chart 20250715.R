# broad sample mergent purposes 
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, ggpubr)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_broad_sample_purpose_type"

#---------------------------------------
# comparison 
cusip <- as.data.table(read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250624_city_cusiplevel_statereq_purpose.dta'))
yield_spread <- as.data.table(read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250701_bond_level_off_yield_spread.dta'))
cusip_merge <- yield_spread[cusip, on = .(issue_id, cusip)]
cusip_merge <- cusip_merge[!is.na(offering_yield_spread)]
cusip_merge <- cusip_merge[city_rev_vote == 0 & !is.na(city_go_vote) & city == 1]

#---------------------------------------
data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta')
data <- as.data.table(data)

data <- data[cusip %in% cusip_merge$cusip]

data <- cusip_merge



#---------------------------------------
# pie chart of bonds and amounts by type of state 
data[, go_unlim_and_lim_vote := ifelse(city_go_vote == 1 & !(state %in% c('WA', 'MI', 'OH')), 1,0)]
data[, go_unlim_only_vote := ifelse(state %in% c('WA', 'MI', 'OH'), 1,0)]
data[, no_vote := ifelse(city_go_vote == 0, 1, 0)]
data[, cat := ifelse(no_vote == 1, 'No_Vote', 
                     ifelse(go_unlim_only_vote == 1, 'GO_Unlim_Only_Vote', 'All_GO_Vote'))]

pie_chart_agg <- data[, list(rev_bonds = sum(rev), 
                             go_unlim_bonds = sum(go_unlim), 
                             go_lim_bonds = sum(go_lim), 
                             rev_amount = sum(amount[rev == 1]), 
                             go_unlim_amount = sum(amount[go_unlim ==1]), 
                             go_lim_amount = sum(amount[go_lim == 1]), 
                             total_amount = sum(amount), 
                             total_bonds = .N
                             ), .(cat)]

# Pie chart for All GO Vote   
all_go_bonds <- pie_chart_agg[cat == 'All_GO_Vote', .(rev_bonds, go_unlim_bonds, go_lim_bonds)]
all_go_bonds <- data.table(t(all_go_bonds))
all_go_bonds[, cat := c('Revenue', 'Unlim. Tax GO', 'Lim. Tax GO')]
colnames(all_go_bonds) <- c('Bonds', 'Category')
all_go_bonds$percentage <- all_go_bonds$Bonds / sum(all_go_bonds$Bonds) * 100 

go_all <- ggplot(all_go_bonds, aes(x = "", y = Bonds, fill = Category, label = paste0(round(percentage), "%"))) +                  
  geom_bar(stat = "identity", width = 1) +                                                                                
  geom_text(position = position_stack(vjust = 0.5), color = 'white', fontface = 'bold', size = 8) +                                                                     
  coord_polar("y") +                                                                                                      
  labs(title = "Panel C: All GO Vote = 1 (N = 74,325 Bonds)") + theme_void()  + scale_fill_grey(start = 0.3, end = 0.8)  + 
  theme(                                                                                                                  
    plot.title = element_text(family = "Times New Roman", hjust = 0.5, size = 20, face = "bold"), 
    legend.text = element_text(size = 20),
    legend.title = element_text(size = 20)
  )     


# GO unlim only
go_unlim_only <- pie_chart_agg[cat == 'GO_Unlim_Only_Vote', .(rev_bonds, go_unlim_bonds, go_lim_bonds)]
go_unlim_only <- data.table(t(go_unlim_only))
go_unlim_only[, cat := c('Revenue', 'Unlim. Tax GO', 'Lim. Tax GO')]
colnames(go_unlim_only) <- c('Bonds', 'Category')
go_unlim_only$percentage <- go_unlim_only$Bonds / sum(go_unlim_only$Bonds) * 100 

go_unlim <- ggplot(go_unlim_only, aes(x = "", y = Bonds, fill = Category, label = paste0(round(percentage), "%"))) +                  
  geom_bar(stat = "identity", width = 1) +                                                                                
  geom_text(position = position_stack(vjust = 0.5), color = 'white', fontface = 'bold', size  = 8) +                                                                     
  coord_polar("y") +                                                                                                      
  labs(title = "Panel B: UTGO Vote = 1 (N = 29,568 Bonds)") + theme_void()  + scale_fill_grey(start = 0.3, end = 0.8)  + 
  theme(                                                                                                                  
    plot.title = element_text(family = "Times New Roman", hjust = 0.5, size = 20, face = "bold"), 
    legend.text = element_text(size = 20),
    legend.title = element_text(size = 20)
  )       

# GO All only
no_vote_bonds <- pie_chart_agg[cat == 'No_Vote', .(rev_bonds, go_unlim_bonds, go_lim_bonds)]
no_vote_bonds <- data.table(t(no_vote_bonds))
no_vote_bonds[, cat := c('Revenue', 'Unlim. Tax GO', 'Lim. Tax GO')]
colnames(no_vote_bonds) <- c('Bonds', 'Category')
no_vote_bonds$percentage <- no_vote_bonds$Bonds / sum(no_vote_bonds$Bonds) * 100 
no_vote_bonds$position <- sum(no_vote_bonds$percentage)- 0.5*no_vote_bonds$percentage

no_vote <- ggplot(no_vote_bonds, aes(x = "", y = Bonds, fill = Category, label = paste0(round(percentage), "%"))) +                  
  geom_bar(stat = "identity", width = 1) +                                                                                
  geom_text(position = position_stack(vjust = 0.5), color = 'white', fontface = 'bold', size = 8) +                                                                     
  coord_polar("y") +                                                                                                      
  labs(title = "Panel A: No Vote (N = 72,050)") + theme_void()  + scale_fill_grey(start = 0.3, end = 0.8)  + 
  theme(                                                                                                                  
    plot.title = element_text(family = "Times New Roman", hjust = 0.5, size = 20, face = "bold"), 
    legend.text = element_text(size = 20),
    legend.title = element_text(size = 20)
  )     


ggarrange(no_vote, go_unlim, go_all, ncol = 3, common.legend = T, legend = 'bottom')



# Pie chart for No Vote                                                                                                   
ggplot(df, aes(x = "", y = No_Vote, fill = category)) +                                                                   
  geom_bar(stat = "identity", width = 1) +                                                                                
  coord_polar("y") +                                                                                                      
  labs(title = "No Vote")                                                                                                 

# Pie chart for GO Unlim Only Vote                                                                                        
ggplot(df, aes(x = "", y = GO_Unlim_Only_Vote, fill = category)) +                                                        
  geom_bar(stat = "identity", width = 1) +                                                                                
  coord_polar("y") +                                                                                                      
  labs(title = "GO Unlim Only Vote")   

#---------------------------------------
# first, show breakdown by amount in vote-requiring and non-vote-requiring
data[, vote := ifelse(city_go_vote == 1, 'Vote Required', 'Vote Not Required')]
vote_by_bond_type <- data[, list(TotalAmount = sum(amount), 
                                 Bonds = .N, 
                                 Yield = mean(offering_yield, na.rm = T)), .(vote, bond_type)]
vote_by_bond_type[, Amount_Cat := sum(TotalAmount) , .(vote)]
vote_by_bond_type[, Bonds_Cat := sum(Bonds) , .(vote)]
vote_by_bond_type[, Amount_Perc := (TotalAmount/Amount_Cat)*100]
vote_by_bond_type[, Bonds_Perc := (Bonds/Bonds_Cat)*100]

vote_by_bond_type <- vote_by_bond_type[, .(vote, bond_type, Yield, Amount_Perc, Bonds_Perc)]

# Plot the data                                                                                                           
amnt_by_type <- ggplot(vote_by_bond_type, aes(x = bond_type, y = Amount_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Amount Percentage by Bond Type and City Go Vote",                                                         
       x = "Bond Type",                                                                                                   
       y = "Amount Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),
                    name = "City GO Vote") +                                                                          
  theme_minimal()   

ggsave(paste0(tables_wd, '/amount_perc_by_bond_type.png'), plot = amnt_by_type )



count_by_type <- ggplot(vote_by_bond_type, aes(x = bond_type, y = Bonds_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Number of Bonds Percentage by Bond Type and City Go Vote",                                                         
       x = "Bond Type",                                                                                                   
       y = "Bond Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") + theme_minimal()
ggsave(paste0(tables_wd, '/count_perc_by_bond_type.png'), plot = count_by_type )

# Plot the data                                                                                                           
yield_by_type <- ggplot(vote_by_bond_type, aes(x = bond_type, y = Yield, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Yield by Bond Type and City Go Vote",                                                         
       x = "Bond Type",                                                                                                   
       y = "Yield") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange")) +                                                                          
  theme_minimal()   
ggsave(paste0(tables_wd, '/yield_by_bond_type.png'), plot = yield_by_type )

# output latex on average yields 
avg_yields <- vote_by_bond_type[, .(vote, bond_type, Yield)][order(vote, bond_type)]
setnames(avg_yields, 'Yield', 'avg_yield')
stargazer(avg_yields, summary = F, type = 'latex', table.placement = 'H', no.space = T, rownames = F,
          title = 'Average Yields by Vote Requirement and Bond Type',
          out = paste0(tables_wd, '/yields_by_type.tex'))

#---------------------------------------
# breakdown by purpose go unlim only
vote_by_purpose <- data[go_unlim == 1, list(TotalAmount = sum(amount), 
                                            Bonds = .N), .(vote, purp_broad)]
vote_by_purpose[, Amount_Cat := sum(TotalAmount) , .(vote)]
vote_by_purpose[, Bonds_Cat := sum(Bonds) , .(vote)]
vote_by_purpose[, Bonds_Perc := (Bonds/Bonds_Cat)*100]
vote_by_purpose[, Amount_Perc := (TotalAmount/Amount_Cat)*100]

amount_by_purpose <- ggplot(vote_by_purpose, aes(x = purp_broad, y = Amount_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Amount Percentage by Bond Purpose and City Go Vote (GO Unlim Only)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Amount Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()  

ggsave(paste0(tables_wd, '/amnt_by_purpose_go_only.png'), plot = amount_by_purpose )

ggplot(vote_by_purpose, aes(x = purp_broad, y = Bonds_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Number Bonds Percentage by Bond Purpose and City Go Vote (GO Unlim Only)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Bond Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()  


# breakdown by purpose, dropping other and genpubimprov
vote_by_purpose_filter <- data[go_unlim == 1 & !(purp_broad %in% c('other', 'genpubimprov')), list(TotalAmount = sum(amount), 
                                                                                   Bonds = .N), .(vote, purp_broad)]
vote_by_purpose_filter[, Amount_Cat := sum(TotalAmount) , .(vote)]
vote_by_purpose_filter[, Bonds_Cat := sum(Bonds) , .(vote)]
vote_by_purpose_filter[, Bonds_Perc := (Bonds/Bonds_Cat)*100]
vote_by_purpose_filter[, Amount_Perc := (TotalAmount/Amount_Cat)*100]

amnt_by_purpose_go_no_general <- ggplot(vote_by_purpose_filter, aes(x = purp_broad, y = Amount_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Amount Percentage by Bond Purpose and City Go Vote (GO Unlim Only, Drop General)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Amount Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()   
ggsave(paste0(tables_wd, '/amnt_by_purpose_go_no_general.png'), plot = amnt_by_purpose_go_no_general )


# breakdown by purpose, dropping other and genpubimprov KEEP ALL BONDS
vote_by_purpose_filter <- data[!(purp_broad %in% c('other', 'genpubimprov')), list(TotalAmount = sum(amount), 
                                                                                                   Bonds = .N), .(vote, purp_broad)]
vote_by_purpose_filter[, Amount_Cat := sum(TotalAmount) , .(vote)]
vote_by_purpose_filter[, Bonds_Cat := sum(Bonds) , .(vote)]
vote_by_purpose_filter[, Bonds_Perc := (Bonds/Bonds_Cat)*100]
vote_by_purpose_filter[, Amount_Perc := (TotalAmount/Amount_Cat)*100]

ggplot(vote_by_purpose_filter, aes(x = purp_broad, y = Amount_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Amount Percentage by Bond Purpose and City Go Vote (ALL BONDS, Drop General)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Amount Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()  

ggplot(vote_by_purpose_filter, aes(x = purp_broad, y = Bonds_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Number of Bonds Percentage by Bond Purpose and City Go Vote (ALL BONDS, Drop General)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Bonds Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal() 


# FOR GO UNLIM, JUST GENERAL VS EVERYTHING ELSE 
data[, general := ifelse(purp_broad %in% c('other', 'genpubimprov'), 'general', 'specific')]
vote_by_purpose_filter <- data[go_unlim == 1, list(TotalAmount = sum(amount), Bonds = .N), .(vote, general)]
vote_by_purpose_filter[, Amount_Cat := sum(TotalAmount) , .(vote)]
vote_by_purpose_filter[, Bonds_Cat := sum(Bonds) , .(vote)]
vote_by_purpose_filter[, Bonds_Perc := (Bonds/Bonds_Cat)*100]
vote_by_purpose_filter[, Amount_Perc := (TotalAmount/Amount_Cat)*100]

ggplot(vote_by_purpose_filter, aes(x = general, y = Amount_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Amount Percentage by General/Specific and City Go Vote (GO Unlim Only, Drop General)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Amount Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()  

ggplot(vote_by_purpose_filter, aes(x = general, y = Bonds_Perc, fill = factor(vote))) +                                          
  geom_bar(stat = "identity", position = "dodge") +                                                                       
  labs(title = "Number of Bonds Percentage by Bond Purpose and City Go Vote (GO Unlim Only, Drop General)" ,                                                         
       x = "Bond Purpose",                                                                                                   
       y = "Bonds Percentage") +                                                                                         
  scale_fill_manual(values = c("lightblue", "orange"),                                                                            
                    name = "City GO Vote") +                                                   
  theme_minimal()   

#===============================================
# t-tests across city_go_vote 
#===============================================
data[, go := ifelse(go_unlim == 1 | go_lim == 1, 1, 0)]
vars_to_test <- c("go", "rev", "go_unlim", "go_lim",                                                                      
                  "purp_broad_arts", "purp_broad_econdev",                                                                
                  "purp_broad_educ", "purp_broad_genpubimprov",                                                           
                  "purp_broad_health", "purp_broad_housing",                                                              
                  "purp_broad_justice", "purp_broad_other",                                                               
                  "purp_broad_parksrec", "purp_broad_pubbldg",                                                            
                  "purp_broad_safety", "purp_broad_transport",                                                            
                  "purp_broad_utilities", "purp_broad_wtrswr")   

# Create t_tests_table   
t_tests_table <- data.table(variable = vars_to_test,                                                                      
                            vote_required = sapply(vars_to_test, function(var) mean(data[[var]][data$city_go_vote == 1])),
                            vote_not_required = sapply(vars_to_test, function(var) mean(data[[var]][data$city_go_vote == 0])),                                                                                                                     
                                                   p_val = sapply(vars_to_test, function(var) {                                                
                                                     t_test <- t.test(data[[var]][data$city_go_vote == 1], data[[var]][data$city_go_vote == 0]) 
                                                     return(t_test$p.value)}))
t_tests_table[, diff := vote_required - vote_not_required]
t_tests_table[, stars := ifelse(p_val < 0.01, '***', 
                                ifelse(p_val < 0.05, '**', 
                                       ifelse(p_val < 0.1, '*', ''))) ]
t_tests_table[, diff := paste0(as.character(round(diff, 3)), stars)]
t_tests_table[, vote_required := round(vote_required, 3)]
t_tests_table[, vote_not_required := round(vote_not_required, 3)]
t_tests_table <- t_tests_table[, .(variable, vote_required, vote_not_required, diff)]


# NOW, T TESTS ACROSS PURPOSES REMOVING GENEARL 
vars_to_test <- c("purp_broad_arts", "purp_broad_econdev",                                                                
                  "purp_broad_educ",                                                           
                  "purp_broad_health", "purp_broad_housing",                                                              
                  "purp_broad_justice",                                                               
                  "purp_broad_parksrec", "purp_broad_pubbldg",                                                            
                  "purp_broad_safety", "purp_broad_transport",                                                            
                  "purp_broad_utilities", "purp_broad_wtrswr")   

data_non_general = data[!(purp_broad %in% c('genpubimprov', 'other'))]

# Create t_tests_table   
t_tests_table2 <- data.table(variable = vars_to_test,                                                                      
                            vote_required = sapply(vars_to_test, function(var) mean(data_non_general[[var]][data_non_general$city_go_vote == 1])),
                            vote_not_required = sapply(vars_to_test, function(var) mean(data_non_general[[var]][data_non_general$city_go_vote == 0])),                                                                                                                     
                            p_val = sapply(vars_to_test, function(var) {                                                
                              t_test <- t.test(data_non_general[[var]][data$city_go_vote == 1], data_non_general[[var]][data_non_general$city_go_vote == 0]) 
                              return(t_test$p.value)}))
t_tests_table2[, diff := vote_required - vote_not_required]
t_tests_table2[, stars := ifelse(p_val < 0.01, '***', 
                                ifelse(p_val < 0.05, '**', 
                                       ifelse(p_val < 0.1, '*', ''))) ]
t_tests_table2[, diff := paste0(as.character(round(diff, 3)), stars)]
t_tests_table2[, vote_required := round(vote_required, 3)]
t_tests_table2[, vote_not_required := round(vote_not_required, 3)]
t_tests_table2 <- t_tests_table2[, .(variable, vote_required, vote_not_required, diff)]


#===============================================
# first get state level averages, then average
#===============================================


# NOW, T TESTS ACROSS PURPOSES REMOVING GENEARL 
vars_to_test <- c("purp_broad_arts", "purp_broad_econdev",                                                                
                  "purp_broad_educ",                                                      
                  "purp_broad_health", "purp_broad_housing",                                                              
                  "purp_broad_justice","purp_broad_genpubimprov",
                  "purp_broad_other",
                  "purp_broad_parksrec", "purp_broad_pubbldg",                                                            
                  "purp_broad_safety", "purp_broad_transport",                                                            
                  "purp_broad_utilities", "purp_broad_wtrswr")   

# Calculate issuer-level averages for city_go_vote == 1                                                                    
state_avg_vote_required <- data[city_go_vote == 1, lapply(.SD, mean), by = seed_issuer, .SDcols = vars_to_test]
state_avg_vote_required[, city_go_vote := 1]

# Calculate state-level averages for city_go_vote == 0                                                                    
state_avg_vote_not_required <- data[city_go_vote == 0, lapply(.SD, mean), by = seed_issuer, .SDcols = vars_to_test]             
state_avg_vote_not_required[, city_go_vote := 0]
# Combine both tables into one                                                                                            
state_avg_combined <- rbind(state_avg_vote_not_required, state_avg_vote_required)


# Create t_tests_table   
t_tests_table <- data.table(variable = vars_to_test,                                                                      
                            vote_required = sapply(vars_to_test, function(var) mean(state_avg_combined[[var]][state_avg_combined$city_go_vote == 1])),
                            vote_not_required = sapply(vars_to_test, function(var) mean(state_avg_combined[[var]][state_avg_combined$city_go_vote == 0])),                                                                                                                     
                            p_val = sapply(vars_to_test, function(var) {                                                
                              t_test <- t.test(state_avg_combined[[var]][state_avg_combined$city_go_vote == 1], 
                                               state_avg_combined[[var]][state_avg_combined$city_go_vote == 0]) 
                              return(t_test$p.value)}))
t_tests_table[, diff := vote_required - vote_not_required]
t_tests_table[, stars := ifelse(p_val < 0.01, '***', 
                                ifelse(p_val < 0.05, '**', 
                                       ifelse(p_val < 0.1, '*', ''))) ]
t_tests_table[, diff := paste0(as.character(round(diff, 3)), stars)]
t_tests_table[, vote_required := round(vote_required, 3)]
t_tests_table[, vote_not_required := round(vote_not_required, 3)]
t_tests_table <- t_tests_table[, .(variable, vote_required, vote_not_required, diff)]



### drop other 
# NOW, T TESTS ACROSS PURPOSES REMOVING GENEARL 
vars_to_test <- c("purp_broad_arts", "purp_broad_econdev",                                                                
                  "purp_broad_educ",                                                      
                  "purp_broad_health", "purp_broad_housing",                                                              
                  "purp_broad_justice",
                  "purp_broad_parksrec", "purp_broad_pubbldg",                                                            
                  "purp_broad_safety", "purp_broad_transport",                                                            
                  "purp_broad_utilities", "purp_broad_wtrswr")   

# Calculate state-level averages for city_go_vote == 1     
data_adj <- data[purp_broad_genpubimprov == 0 & purp_broad_other == 0]
state_avg_vote_required <- data_adj[city_go_vote == 1, lapply(.SD, mean), by = seed_issuer, .SDcols = vars_to_test]
state_avg_vote_required[, city_go_vote := 1]

# Calculate state-level averages for city_go_vote == 0                                                                    
state_avg_vote_not_required <- data_adj[city_go_vote == 0, lapply(.SD, mean), by = seed_issuer, .SDcols = vars_to_test]             
state_avg_vote_not_required[, city_go_vote := 0]
# Combine both tables into one                                                                                            
state_avg_combined <- rbind(state_avg_vote_not_required, state_avg_vote_required)


# Create t_tests_table   
t_tests_table <- data.table(variable = vars_to_test,                                                                      
                            vote_required = sapply(vars_to_test, function(var) mean(state_avg_combined[[var]][state_avg_combined$city_go_vote == 1])),
                            vote_not_required = sapply(vars_to_test, function(var) mean(state_avg_combined[[var]][state_avg_combined$city_go_vote == 0])),                                                                                                                     
                            p_val = sapply(vars_to_test, function(var) {                                                
                              t_test <- t.test(state_avg_combined[[var]][state_avg_combined$city_go_vote == 1], 
                                               state_avg_combined[[var]][state_avg_combined$city_go_vote == 0]) 
                              return(t_test$p.value)}))
t_tests_table[, diff := vote_required - vote_not_required]
t_tests_table[, stars := ifelse(p_val < 0.01, '***', 
                                ifelse(p_val < 0.05, '**', 
                                       ifelse(p_val < 0.1, '*', ''))) ]
t_tests_table[, diff := paste0(as.character(round(diff, 3)), stars)]
t_tests_table[, vote_required := round(vote_required, 3)]
t_tests_table[, vote_not_required := round(vote_not_required, 3)]
t_tests_table <- t_tests_table[, .(variable, vote_required, vote_not_required, diff, p_val)]


#===============================================
# do rev bonds have higher yields than go
#===============================================

test <- felm(offering_yield_tr ~ rev + ln_amount_tr + ln_maturity_tr + callable + sinkable + rated|yrmonth + purp_broad + seed_issuer_id|0|issue_id, data = data)
test <- felm(offering_yield_tr ~ rev*city_go_vote + ln_amount_tr + ln_maturity_tr + callable + sinkable + rated|yrmonth + purp_broad + seed_issuer_id|0|issue_id, data = data)


#===============================================
# are cities more likely to issue go or rev
#===============================================
data[, go := ifelse(go_lim == 1 | go_unlim == 1, 1, 0)]
issue_lvl <- data[, list(rev = first(rev), go = first(go),  go_unlim = first(go_unlim), go_lim = first(go_lim),
                         city_go_vote = first(city_go_vote), 
                         city_rev_vote = first(city_rev_vote), 
                         year = first(year), purp_broad = first(purp_broad)), .(seed_issuer_id,state, issue_id)]
test <- felm(go_lim ~ city_go_vote*city_rev_vote|year + purp_broad|0|state, data = issue_lvl[city_rev_vote == 0])

#---------------------------------------
# issuer_level yields 
data[, high_rated := ifelse(rating_f %in% c('AAA', 'AA', 'AA+')|
                              rating_m %in% c('AAA', 'AA', 'AA+')| 
                            rating_s %in% c('Aaa', 'Aa1', 'Aa2'), 1, 0)]

issuer_level <- data[, list(weighted_mean_yield = weighted.mean(offering_yield_tr, amount, na.rm = T), 
                            mean_yield = mean(offering_yield_tr, na.rm = T),
                            high_rated = mean(high_rated), 
                            rated = mean(rated),
                            amount = sum(amount), 
                            bonds = .N, 
                            issuances = uniqueN(issue_id)), .(seed_issuer_id, city_go_vote, state)]
issuer_level[, ln_amount := log(amount)]

# join with state_level 
state_level <- unique(data[, .(seed_issuer_id, state_ltgo_allowed, state_fullfaith, state_go_vote,
                        state_sep_debtservice_levy, state_sep_pledgerev, state_statutorylien)])
demo <- data[, list(emp = mean(ln_emp, na.rm = T), 
                    pers_inc = mean(ln_pers_inc, na.rm = T), 
                    percap_inc = mean(ln_percap_inc, na.rm = T), 
                    gdp = mean(ln_gdp, na.rm = T), 
                    pop_ln = mean(ln_pop, na.rm = T), 
                    pop = mean(pop, na.rm = T)), .(seed_issuer_id)]
issuer_level <- state_level[issuer_level, on = .(seed_issuer_id)]
issuer_level <- demo[issuer_level, on = .(seed_issuer_id)]

desc <- issuer_level[, .(weighted_mean_yield, mean_yield, 
                         ln_amount, issuances)]
stargazer(desc, min.max = T, median = T, iqr = T, 
          no.space = T, table.placement = 'H', type = 'latex',
          covariate.labels = c('Weighted Avg Yield', 'Avg Yield', 'Amount', 'Issuances'),
          title = 'Issuer-Level Descriptives', digits = 2, 
          out = paste0(tables_wd, '/issuer_level_desc.tex'))

issuer_level[, go_unlim_and_lim_vote := ifelse(city_go_vote == 1 & !(state %in% c('WA', 'MI', 'OH')), 1,0)]
reg1 <- felm(weighted_mean_yield ~ city_go_vote + ln_amount + gdp + pers_inc + percap_inc + emp +
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien
               |0|0|state, data = issuer_level[go_unlim_and_lim_vote == 0])

reg2 <- felm(weighted_mean_yield ~ city_go_vote + ln_amount + issuances + gdp + pers_inc + percap_inc + emp|0|0|state, data = issuer_level)

reg3 <- felm(weighted_mean_yield ~ city_go_vote + ln_amount + issuances +  gdp + pers_inc + percap_inc + emp + state_go_vote +
              state_ltgo_allowed + 
              state_fullfaith + state_sep_debtservice_levy + 
              state_sep_pledgerev + state_statutorylien|0|0|state, data = issuer_level)

stargazer(reg1, reg2, reg3, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Issuer-Level Weighted Averaeg Yields',
          dep.var.labels = c("Weighted Average Yield"),
          covariate.labels = c("City GO Vote", "Amount", "Issuances", "GDP", "Pers Inc","Percap Inc", "Emp", 
                               "State-level GO Vote", "Limited TAX Go allowed", "Full faith and credit pledge",
                               "Separate levy for debt service", "Seperate fundf or pledged prop tax", "Statutory lien on prop tax"),
          add.lines = list(c("Cluster", "State", "State", "State")),
          out = paste0(tables_wd, '/issuer_level_yield_regs.tex')
)


#========================
# issuer-level debt composition 

issuer_level <- data[, list(rev = sum(amount[rev == 1]), 
                            go_unlim = sum(amount[go_unlim == 1]), 
                            go_lim = sum(amount[go_lim ==1]),
                            amount = sum(amount), 
                            bonds = .N, 
                            issuances = uniqueN(issue_id)), .(seed_issuer_id, city_go_vote, state)]
issuer_level[, rev_fraction := rev/amount]
issuer_level[, go_unlim_fraction := go_unlim/amount]
issuer_level[, go_lim_fraction := go_lim/amount]
issuer_level[, ln_amount := log(amount)]


# join with state_level 
state_level <- unique(data[, .(seed_issuer_id, state_ltgo_allowed, state_fullfaith, state_go_vote,
                               state_sep_debtservice_levy, state_sep_pledgerev, state_statutorylien)])
demo <- data[, list(emp = first(ln_emp), 
                    pers_inc = first(ln_pers_inc), 
                    percap_inc = first(ln_percap_inc), 
                    gdp = first(ln_gdp), 
                    pop_ln = first(ln_pop), 
                    pop = first(pop)), .(seed_issuer_id)]
issuer_level <- state_level[issuer_level, on = .(seed_issuer_id)]
issuer_level <- demo[issuer_level, on = .(seed_issuer_id)]
issuer_level[, city_unlim_vote_only := ifelse(state %in% c('WA', 'MI', 'OH'), 1, 0)]
issuer_level[, all_go_vote := ifelse(city_go_vote == 1 & city_unlim_vote_only == 0, 1, 0)]
issuer_level[, go_fraction := go_unlim_fraction + go_lim_fraction]

issuer_level[, city_all_go_vote := ifelse(city_go_vote == 1 & city_unlim_vote_only == 0, 1, 0)]
reg1 <- felm(go_lim_fraction ~ city_unlim_vote_only  +  gdp + pers_inc + percap_inc + emp + state_go_vote +
               state_ltgo_allowed |0|0|state, data = issuer_level[city_all_go_vote == 0])

reg3 <- felm(go_lim_fraction ~ all_go_vote + city_unlim_vote_only +  gdp + pers_inc + percap_inc + emp +state_ltgo_allowed|0|0|state, data = issuer_level)

reg3 <- felm(rev_fraction ~ city_go_vote  +  gdp + pers_inc + percap_inc + emp + state_go_vote +
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|0|0|state, data = issuer_level)

#========================
# bond level 
data[, state_year := paste0(state, year)]
data[, city_unlim_vote_only := ifelse(state %in% c('WA', 'MI', 'OH'), 1, 0) ]
data[, go := ifelse(go_unlim == 1 | go_lim == 1, 1, 0)]
data[, city_go_lim_vote := ifelse(city_go_vote == 1 & city_unlim_vote_only == 0, 1, 0)]
reg1 <- felm(rev ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|state, data = data)
reg2 <- felm(rev ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|state, data = data)
reg3 <- felm(go_lim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|state, data = data)
reg4 <- felm(go_lim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|state, data = data)
reg5 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|state, data = data)
reg6 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|state, data = data)

stargazer(reg1, reg2, reg3, reg4, reg5, reg6, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Bond Type and Vote Requirements',
          dep.var.labels = c("Revenue", 'Limited GO', 'Unlimited GO'),
          covariate.labels = c("City Unlim Vote Req", "City Unlim and Lim GO Vote Req", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp", 
                               "State-level GO Vote", "Limited TAX Go allowed", "Full faith and credit pledge",
                               "Separate levy for debt service", "Seperate fundf or pledged prop tax", "Statutory lien on prop tax"),
          add.lines = list(c("Purpose FE", "Yes", "Yes", "Yes", 'Yes', 'Yes', 'Yes'), 
                           c("Year FE", 'Yes', 'Yes', 'Yes', 'Yes', 'Yes', 'Yes'),
            c("Cluster", "State", "State", "State", "State", "State", "State")),
          out = paste0(tables_wd, '/bond_type_regs_state_cluster.tex'))
# issue id cluster

reg1 <- felm(rev ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg2 <- felm(rev ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)
reg3 <- felm(go_lim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg4 <- felm(go_lim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)
reg5 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg6 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)

stargazer(reg1, reg2, reg3, reg4, reg5, reg6, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Bond Type and Vote Requirements',
          dep.var.labels = c("Revenue", 'Limited GO', 'Unlimited GO'),
          covariate.labels = c("City Unlim Vote Req", "City Unlim and Lim GO Vote Req", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp", 
                               "State-level GO Vote", "Limited TAX Go allowed", "Full faith and credit pledge",
                               "Separate levy for debt service", "Seperate fundf or pledged prop tax", "Statutory lien on prop tax"),
          add.lines = list(c("Purpose FE", "Yes", "Yes", "Yes", 'Yes', 'Yes', 'Yes'), 
                           c("Year FE", 'Yes', 'Yes', 'Yes', 'Yes', 'Yes', 'Yes'),
                           c("Cluster", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue")),
          out = paste0(tables_wd, '/bond_type_regs_issue_cluster.tex'))


data[]
reg1 <- felm(rev ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg2 <- felm(rev ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)
reg3 <- felm(go_lim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg4 <- felm(go_lim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)
reg5 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote|year + purp_broad|0|issue_id, data = data)
reg6 <- felm(go_unlim ~ city_go_vote + city_go_lim_vote + ln_amount +
               ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp + 
               state_ltgo_allowed + 
               state_fullfaith + state_sep_debtservice_levy + 
               state_sep_pledgerev + state_statutorylien|year + purp_broad|0|issue_id, data = data)
