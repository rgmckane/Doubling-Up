library(srvyr)
library(dplyr)
library(tidyverse)
library(robsurvey)

#please contact Molly Richard (Vanderbilt Univeristy) for the dataset and information on variable choice
#or for the same code in SAS


data1 <- read.csv("~/Downloads/usa_00102.csv",  blank.lines.skip = TRUE) 
names(data1) #names of variables
length(data1$YEAR) #number of observations


data1$STATEFIP <- as.character(data1$STATEFIP)
data1$PUMA <- as.character(data1$PUMA)
data0 <- data1 %>% unite("GEOID", c(STATEFIP,PUMA), remove = FALSE, sep = "") 


area_data <- data0 %>%
 dplyr::filter(OWNERSHP== 2, BEDROOMS == 3, KITCHEN == 4, PLUMBING == 20,PERNUM == 1) %>% 
  group_by(GEOID) %>%
  summarise(AMGR = weighted_median(RENTGRS, HHWT))

data2 <- left_join(data0,area_data,  by = "GEOID")

data3 <- data2 %>% mutate(adjustment = ifelse(OWNERSHP == 1 & MORTGAGE == 1, .402*(AMGR/1086) + .598,
ifelse(OWNERSHP == 1 & MORTGAGE == 2 | MORTGAGE == 3  | MORTGAGE == 4, .504*(AMGR/1086) +.496,
                                        ifelse(OWNERSHP == 2 & MORTGAGE == 0, .514*(AMGR/1086) + .486, NA))),
  
                         adjustedpoverty_head = POVERTY_HEAD*(1/adjustment), 
                         adjustedpoverty = POVERTY*(1/adjustment), 
                         roundedadjustedpoverty = round(adjustedpoverty, 0),
                         roundedadjustedpoverty_head = round(adjustedpoverty_head,0),
  
                        overcrowded = ifelse((NUMPREC/2)>(BEDROOMS-1), 1, 0),
  
                        DUrelative = ifelse(RELATE  %in% c(5,6,7,8,10)  & AGE < 65, 1,0),
  
                       special1 = ifelse(RELATE == 7 & AGE < 18 & MOMLOC== 0 & POPLOC == 0, 1, 0),
  
                       special2 = ifelse(RELATE == 7 & AGE > 17 & MOMLOC== 0 & POPLOC == 0 & MOMLOC_HEAD == 0  & 
                                     POPLOC_HEAD == 0 & SPLOC == 0 & SPLOC_HEAD == 0 &
                                          NCHILD == 0 & NCHILD_HEAD == 0, 1, 0),
                                          
                       DUrelative = ifelse(special1 == 1 | special2 == 1, 0, DUrelative),
  
                       DUolderrelative = ifelse(RELATE  %in% c(5,6,7,8,10) & AGE >= 65 & overcrowded == 1, 1,0),
                  
                       DUmiddlegen = ifelse(RELATE %in% c(3,4) & SFTYPE %in% c(3,4) & AGE >=18, 1,0),
  
                       DUmarriedchild = ifelse(RELATE %in% c(3,4) & SFTYPE %in% c(1,2), 1,0),
  
                       DUgrandchild = ifelse(RELATE !=  9, 0, 
                                        ifelse(RELATE == 9 & GCRESPON_HEAD == 2 & AGE < 18, 0, 
                                          ifelse(RELATE == 9 & SFTYPE == 4  & AGE_MOM<18, 0,
                                            ifelse(RELATE == 9 & SFTYPE == 3 &  AGE_POP<18, 0, 1)))),
  
                      DUsingadcrowd = ifelse(RELATE %in% c(3,4) & SFTYPE == 0 & AGE >17 & overcrowded == 1, 1, 0),
  
                      DUnonrelative = ifelse(RELATED == 1260, 1, 0),
                      
                      special6 = ifelse(RELATED == 1260 & (RELATED_MOM %in% 1114 | RELATED_POP %in% 1114) & 
                                           (AGE<18 | (AGE>=18 & overcrowded==0)),1,0), 
    
                      DUnonrelative = ifelse(special6 == 1, 0, DUnonrelative),

                      povertylev = ifelse(roundedadjustedpoverty_head <= 125 & roundedadjustedpoverty <= 125, 1, 0),

                      DU1 = ifelse( povertylev == 1 & DUmiddlegen == 1, 1, 0),
  
                      DU2 = ifelse( povertylev == 1 & DUrelative == 1, 1, 0),
                
                      DU3 = ifelse( povertylev == 1 & DUgrandchild == 1, 1, 0),
  
                      DU4 = ifelse( povertylev == 1 & DUmarriedchild == 1, 1, 0),
  
                      DU5 = ifelse( povertylev == 1 & DUnonrelative == 1, 1, 0),

                      DU6 = ifelse( povertylev == 1 & DUsingadcrowd == 1, 1, 0),
  
                      DU7 = ifelse( povertylev == 1 & DUolderrelative == 1, 1, 0),
               
                     doubledup = ifelse(DU1 == 1 | DU2 == 1 | DU3 == 1 |DU4 == 1 | DU5 == 1 |
                                        DU6 == 1 | DU7 == 1, 1,0 ))

person_weighted <- data3 %>% as_survey_design(weights = PERWT, repweights = matches("REPWTP[0-9]+"), 
                   type = "JK1", scale = 4/ 80 , rscales = rep(1, 80 ), mse = TRUE)

person_weighted %>% summarise(survey_total(doubledup))

