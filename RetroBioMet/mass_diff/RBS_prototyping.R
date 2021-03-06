# Human Retrobiosynthesis 
# Dependencies
library(compiler)
library(devtools)
library(rJava)
library(rcdk)
library(tidyverse)
library(MetaboCoreUtils)

## Set working directory
setwd("C:/MetClassNet/Retrobiosyn/RetroBioMet/RetroBioMet/")

## Match and find MXN IDs based on your input MXN IDs ##

#### Load dataset 
org_rxn <- read.csv("data/Human1_network_reactions.csv") # Load organism (here based on Human1 GSMN) reaction list with MetaNetX IDs
rxnRuleDB <- read.csv("data/retrorules_rr02_flat_all.csv") # Load reaction rules database

##############################################################
### Matching of MetaNetX IDs from organism to reaction rules

#### Function to match MetaNetX (MXN) IDs across reaction rule database and organism reaction list
metanetx_match <- function(organism_Rxn, rxnRuleDB, colOrg_name, colRR_name){
  print("Reaction MetaNetX IDs matching is running...")
  print("Please be patient it may take quite some time")
  output <- matrix(nrow = 0, ncol = length(colnames(rxnRuleDB)))
  colnames(output) <- colnames(rxnRuleDB)
  # for loop to run through the whole list of reactions IDs from organism
  for(i in 1:length(organism_Rxn[,1])){
      # match strings of MetaNetX (MXN) IDs of organism with reaction rules database IDs
      r <- which(rxnRuleDB[,colRR_name]==organism_Rxn[i,colOrg_name])
      if(identical(r, integer(0))){
        # If no match move to next ID
        next
      }else{
        # Append reaction rules rows matching to output matrix
        output <- rbind(output,rxnRuleDB[r,])
      }     
  }
  assign("RR_Org",output, envir = globalenv()) #save output in global environment
  length(RR_Org[,1]);print("reaction rules were matched to the organism reaction list")
  }
metanetx_match <- cmpfun(metanetx_match) # compile function

#### Run function to match MXN IDs (takes a while)
metanetx_match(organism_Rxn = org_rxn,rxnRuleDB = rxnRuleDB,
               colOrg_name = "metanetx.reaction", colRR_name = "Reaction_ID")

#### Export file to csv
write.csv(RR_Org,file = "mass_diff/outputs/output_rxnRules_Org.csv")

###################################################
## Get the formula, mass, and atoms count for each reaction substrates and products 

# The aim is to be used later on to calculate the mass differences between products and substrates

#RR_Org <- read.csv("mass_diff/outputs/output_rxnRules_Org.csv") #should already be a variable in global env 

RR_OrgMOL <- cbind(RR_Org, matrix(data=NA, ncol=8, nrow=length(RR_Org[,1])))
colnames(RR_OrgMOL) <- c(colnames(RR_Org),"Substrat_Formula","Substrat_AtomsNum",
                       "Substrat_AVGMass", "Substrat_ExMass", "Product_Formula",
                      "Product_AtomsNum", "Product_AVGMass","Product_ExMass")
## Calculate molecules characteristics based on their SMILES structures using the rCDK package
  # Infos on rCDK package and java data processing below
  # https://cran.r-project.org/web/packages/rcdk/vignettes/using-rcdk.html

### Substrate SMILES processing
substrate_MolChar <- function(RR_OrgMOL){
  print("Substrate structure list characteristics calculation started...")
  print("Please be patient this one is very slow as it uses CDK via Java and calculate each characteristics individually")
  options("java.parameters"=c("-Xmx4000m"))
  for (i in 1:length(RR_OrgMOL[,1])) {
    smile <- RR_OrgMOL$Substrate_SMILES[i]
    m <- parse.smiles(smile)[[1]]
    ## Use CDK functions to calculate the characteristics of each SMILES
    sub_atomsNum <- get.atom.count(m) # Number of atoms in molecule
    sub_ExMass <- get.exact.mass(m)  # Calculate Exact Mass
    sub_formulaMol <- get.mol2formula(m) # Calculate Formula characteristics
    sub_formula <- sub_formulaMol@string # Get Formula Strings
    sub_AVGMass <- get.natural.mass(m) # Calculate the Average Mass
    mol_info <- cbind(sub_formula, sub_atomsNum, sub_AVGMass, sub_ExMass)
    .jcall("java/lang/System","V","gc")
    gc()
    RR_OrgMOL[i,20:23] <- mol_info
  }
  assign("RR_OrgMOL",RR_OrgMOL, envir = globalenv()) #save output in global environment
  print("Substrate characteristics are now calculated and stored in RR_OrgMOL")
}
substrate_MolChar <- cmpfun(substrate_MolChar)
substrate_MolChar(RR_OrgMOL = RR_OrgMOL)

#### Can export file to csv just in case
# write.csv(RR_OrgMOL,file = "mass_diff/outputs/output_rxnRules_Org_Char.csv")

### Product SMILES processing and calculation of individual molecule characteristics
product_MolChar <- function(RR_OrgMOL){
  print("Product structure list characteristics calculation started...")
  print("Please be patient this one is very slow as it uses CDK via Java and calculate each characteristics individually")
  options("java.parameters"=c("-Xmx4000m"))
  for (i in 1:length(RR_OrgMOL[,1])) {
    smile <- RR_OrgMOL$Product_SMILES[i]
    m <- parse.smiles(smile)[[1]]
    ## Use CDK functions to calculate the characteristics of each SMILES
    sub_atomsNum <- get.atom.count(m) # Number of atoms in molecule
    sub_ExMass <- get.exact.mass(m)  # Calculate Exact Mass
    sub_formulaMol <- get.mol2formula(m) # Calculate Formula characteristics
    sub_formula <- sub_formulaMol@string # Get Formula Strings
    sub_AVGMass <- get.natural.mass(m) # Calculate the Average Mass
    mol_info <- cbind(sub_formula, sub_atomsNum, sub_AVGMass, sub_ExMass)
    .jcall("java/lang/System","V","gc")
    gc()
    RR_OrgMOL[i,24:27] <- mol_info
  }
  assign("RR_OrgMOL",RR_OrgMOL, envir = globalenv()) #save output in global environment
  print("Product characteristics are now calculated and stored in RR_OrgMOL")
}
product_MolChar <- cmpfun(product_MolChar)
product_MolChar(RR_OrgMOL = RR_OrgMOL)

#### Export file to csv
write.csv(RR_OrgMOL,file = "mass_diff/outputs/output_rxnRules_Org_Char.csv")

######################################################
# Input data from human to generate mass diff list

#### Save as a separate value to modify as it takes a while to read the original file
mass_diff <- as.data.frame(RR_OrgMOL)

#### Calculate average mass differences
mass_diff$AVGmass_diff <- abs(as.numeric(mass_diff$Substrat_AVGMass)-as.numeric(mass_diff$Product_AVGMass))
#### Calculate exact mass differences
mass_diff$Exactmass_diff <- abs(as.numeric(mass_diff$Substrat_ExMass)-as.numeric(mass_diff$Product_ExMass))
#### Calculate atom differences
mass_diff$NumAtoms_diff <- abs(as.numeric(mass_diff$Substrat_AtomsNum)-as.numeric(mass_diff$Product_AtomsNum))


### Define formula for the mass diff
#### Mass diff formula calculation function:
MassDiffFormula <- function(Substrate_Formula, Product_Formula){
  # Part 1: extract elements from formula
  SUBF <- MetaboCoreUtils::countElements(Substrate_Formula)
  SUBF <- as.matrix(SUBF)
  SUBF <- cbind(rownames(SUBF), data.frame(SUBF, row.names=NULL))
  PRODF <- MetaboCoreUtils::countElements(Product_Formula)
  PRODF <- as.matrix(PRODF)
  PRODF <- cbind(rownames(PRODF), data.frame(PRODF, row.names=NULL))
  
  # Part 2: calculate number of elements in both substrate and product then match them in a matrix
  SPF = matrix(NA,ncol=3,nrow = length(PRODF[,1]))
  for(i in 1:length(PRODF[,1])){
    n <- which(SUBF[,1]==PRODF[i,1])
    if(length(n)>0){
      SPF[i,] <- as.matrix(cbind(PRODF[i,1],PRODF[i,2],SUBF[n,2]))
    }
    else{
      SPF[i,] <- as.matrix(cbind(PRODF[i,1],PRODF[i,2],0))
    }
  }
  # Calculate the difference of elements between product and substrate
  SPF=cbind(SPF, as.matrix(as.numeric(SPF[,2])-as.numeric(SPF[,3])))
  SPFX=as.array(as.numeric(SPF[,4])) #conversion to data array to be readable by pasteElements
  rownames(SPFX)=SPF[,1]
  # Get formula from elements numbers
  FORMULA= MetaboCoreUtils::pasteElements(SPFX)
  rm(SUBF,PRODF,SPF,SPFX)
  #Output
  FORMULA
}

#### Add column for massdiff formula
mass_diff$massdiffFormula = NA

#### Run the function to generate all formula for mass difference across all row
for(j in 1:length(mass_diff$Substrat_Formula)){
  mass_diff$massdiffFormula[j] <- MassDiffFormula(Substrate_Formula = mass_diff$Substrat_Formula[j],Product_Formula = mass_diff$Product_Formula[j])
}

#### Export to file
write.csv(mass_diff, "mass_diff/outputs/massdiff_list_all.csv")

#################################################
# Generate a list of unique masses with the formula associated to the mass diff
mass_diff_Form <- as.data.frame(mass_diff)
mass_diff_Form <- as_tibble(mass_diff_Form) # save as tibble for tidyverse

#### Only extract unique Exact mass
mass_diff_Form_Unique <- mass_diff_Form %>%
  distinct(Exactmass_diff, .keep_all = TRUE)

#### Export list of unique mass diff
write.csv(mass_diff_Form_Unique, "mass_diff/outputs/unique_mass_diff_list.csv")

