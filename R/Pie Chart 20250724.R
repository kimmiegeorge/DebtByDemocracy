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




#---------------------------------------
# pie charts by state 
 


state_plot_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Composition Plots'

for (s in unique(data$state)){
  
  
  agg <- data[state == s, list(rev_bonds = sum(rev), 
                               go_unlim_bonds = sum(go_unlim), 
                               go_lim_bonds = sum(go_lim), 
                               rev_amount = sum(amount[rev == 1]), 
                               go_unlim_amount = sum(amount[go_unlim ==1]), 
                               go_lim_amount = sum(amount[go_lim == 1]), 
                               total_amount = sum(amount), 
                               total_bonds = .N
  ), .(cat)]
  issuers = format(uniqueN(data[state == s]$seed_issuer_id), big.mark = ',')
  agg = agg[state == state, .(rev_bonds, go_unlim_bonds, go_lim_bonds)]
  agg <- data.table(t(agg))
  agg[, cat := c('Revenue', 'Unlim. Tax GO', 'Lim. Tax GO')]
  colnames(agg) <- c('Bonds', 'Category')
  agg$percentage <- agg$Bonds / sum(agg$Bonds) * 100 
  
  state_plot <- ggplot(agg, aes(x = "", y = Bonds, fill = Category, label = paste0(round(percentage), "%"))) +                  
    geom_bar(stat = "identity", width = 1) +                                                                                
    geom_text(position = position_stack(vjust = 0.5), color = 'white', fontface = 'bold', size = 8) +                                                                     
    coord_polar("y") +                                                                                                      
    labs(title = paste0(s, '(', issuers, ' issuers)')) + theme_void()  + scale_fill_grey(start = 0.3, end = 0.8)  + 
    theme(                                                                                                                  
      plot.title = element_text(family = "Times New Roman", hjust = 0.5, size = 20, face = "bold"), 
      legend.text = element_text(size = 20),
      legend.title = element_text(size = 20)
    )     
  
  ggsave(state_plot, filename = paste0(state_plot_dir, '/', s, '.png'), height = 8, width = 8)
  
}



# output state debt chars 
state_debt_chars <- unique(data[, .(state, city_go_vote, state_go_vote, state_ltgo_allowed, glm_proactive, 
                                    state_sep_debtservice_levy, state_sep_pledgerev, state_statutorylien)])
state_debt_chars <- state_debt_chars[order(state)]
write.csv(state_debt_chars, paste0(state_plot_dir, '/state_debt_chars.csv'))

