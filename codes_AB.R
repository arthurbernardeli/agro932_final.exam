#-----------------------------------------------------#
#-----Codes developed by Arthur Bernardeli------------#
#-----AGRO 992 - Spring 2025--------------------------#
#-----Part 1: codes used for the Midterm assignment---#
#-----Part 2: codes used for the Final assignment-----#
#-----------------------------------------------------#

#----------------#
#-----PART 1-----#
#----------------#

setwd("C:\\Users\\arthu\\Desktop\\Midterm")
rm(list=ls())

#Simulating Genotypes and Phenotypes for the Founder Population

library(AlphaSimR)

#Step 1: Create founder population
set.seed(123)  # for reproducibility
founderPop <- runMacs(nInd = 40, nChr = 20, segSites = 6000, species = "GENERIC")

#Step 2: Define simulation parameters with correlated traits
SP <- SimParam$new(founderPop)
SP$addTraitA(
  nQtlPerChr = 30,
  mean = c(0, 0),
  var = c(1, 1),
  corA = matrix(c(1, -0.45, -0.45, 1), 2)
)
SP$setVarE(h2 = c(0.45, 0.70))

#SNP chip
SP$addSnpChip(nSnpPerChr = 300)

#Step 3: Generate populations
pop_all <- newPop(founderPop)
pop_yield <- pop_all[1:20]
pop_protein <- pop_all[21:40]

#Step 4: Simulate phenotypes
pop_yield <- setPheno(pop_yield)
pop_protein <- setPheno(pop_protein)

#Step 5: Rescale phenotypes to realistic values
scale_to_range <- function(x, new_min, new_max) {
  old_min <- min(x)
  old_max <- max(x)
  scaled <- (x - old_min) / (old_max - old_min)
  return(scaled * (new_max - new_min) + new_min)
}

#Pop Yield group: rescale
df_yield <- as.data.frame(pheno(pop_yield))
colnames(df_yield) <- c("Yield", "Protein")
df_yield$Yield <- scale_to_range(df_yield$Yield, 75, 95)
df_yield$Protein <- scale_to_range(df_yield$Protein, 32, 37)

#Pop Protein group: rescale
df_protein <- as.data.frame(pheno(pop_protein))
colnames(df_protein) <- c("Yield", "Protein")
df_protein$Yield <- scale_to_range(df_protein$Yield, 33, 54)
df_protein$Protein <- scale_to_range(df_protein$Protein, 48, 63)

#Add strain labels
df_yield$Strain <- paste0("y", seq_len(nrow(df_yield)))
df_protein$Strain <- paste0("p", seq_len(nrow(df_protein)))

#Step 6: Extract genotypes
geno_yield <- pullSnpGeno(pop_yield)
geno_protein <- pullSnpGeno(pop_protein)

#Set row names of genotype matrices using strain IDs
rownames(geno_yield) <- df_yield$Strain
rownames(geno_protein) <- df_protein$Strain


#Step 7: Preview results
head(df_yield)
head(df_protein)

#Step 8: 3D-PCA between founder populations
library(plotly)

#Combine genotypes and label populations
geno_all <- rbind(geno_yield, geno_protein)
pca_labels <- c(rep("Yield", nrow(geno_yield)), rep("Protein", nrow(geno_protein)))

#Run PCA
pca_res <- prcomp(geno_all, scale. = TRUE)

#Extract first 3 PCs
pc_df <- as.data.frame(pca_res$x[, 1:3])
pc_df$Group <- pca_labels

#Run PCA (if not already done)
pca_res <- prcomp(geno_all, scale. = TRUE)

#Extract proportion of variance explained
pve <- (pca_res$sdev^2) / sum(pca_res$sdev^2)
percent_var <- round(pve[1:3] * 100, 2)  # Use this for labeling axes


#3D PCA Plot using plotly
#Create 3D PCA plot with % variance in labels
fig <- plot_ly(pc_df, 
               x = ~PC1, y = ~PC2, z = ~PC3,
               color = ~Group,
               colors = c("royalblue", "firebrick"),
               type = 'scatter3d',
               mode = 'markers',
               marker = list(size = 5)) %>%
  layout(title = "3D PCA of Genotypes Between Founder Populations",
         scene = list(
           xaxis = list(title = paste0("PC1 (", percent_var[1], "%)")),
           yaxis = list(title = paste0("PC2 (", percent_var[2], "%)")),
           zaxis = list(title = paste0("PC3 (", percent_var[3], "%)"))
         ))


#View it
fig


#Calculating Fst
library(dplyr)

#Combine and label
geno_all <- rbind(geno_yield, geno_protein)
pop_labels <- c(rep("yield", nrow(geno_yield)), rep("protein", nrow(geno_protein)))

#Function to calculate FST per SNP (basic method)
calc_fst_basic <- function(geno, pop) {
  fst_vals <- apply(geno, 2, function(marker) {
    freq1 <- mean(marker[pop == "yield"], na.rm = TRUE) / 2
    freq2 <- mean(marker[pop == "protein"], na.rm = TRUE) / 2
    p_bar <- (freq1 + freq2) / 2
    num <- (freq1 - freq2)^2
    den <- p_bar * (1 - p_bar)
    if (den == 0) return(NA)
    return(num / den)
  })
  return(fst_vals)
}

#Run on all markers
fst_snps <- calc_fst_basic(geno_all, pop_labels)

#Chromosome index (adjust if needed)
chr_info <- rep(1:20, each = 300)

#Per-chromosome FST (mean of marker FSTs)
fst_by_chr <- tapply(fst_snps, chr_info, mean, na.rm = TRUE)

#Genome-wide FST
fst_global <- mean(fst_snps, na.rm = TRUE)

#Output
cat("Genome-wide FST:\n")
print(fst_global)

cat("\n FST per chromosome:\n")
print(fst_by_chr)

#Calculate mean FST across chromosomes
mean_fst <- mean(fst_by_chr, na.rm = TRUE)

#Save the plot with the mean line and label
png("fst_by_chromosome.png", width = 800, height = 600)

barplot(fst_by_chr,
        main = "Chromosome-wise FST (Between Founder Populations)",
        ylab = "FST",
        xlab = "Chromosome",
        col = "darkorange",
        las = 2,
        ylim = c(0, max(fst_by_chr, na.rm = TRUE) + 0.05))  # make space for the line

#Add mean FST line
abline(h = mean_fst, col = "blue", lty = 2, lwd = 2)

#Add text label for mean
text(x = 1, y = mean_fst + 0.01, 
     labels = paste0("Mean FST = ", round(mean_fst, 3)), 
     col = "blue", pos = 4)

dev.off()

#Selection and Breeding Cycles in Yield and Protein Populations

library(AlphaSimR)
library(ggplot2)
library(dplyr)

yield_base <- pop_yield

#Set output directory
output_base <- "C:/Users/arthu/Desktop/Midterm/Selection_Cycles"

#Create output subdirectories if they don't exist
subfolders <- c("yield/phenotypes", "yield/fst_vs_founder", "yield/fst_vs_protein", "yield/pca",
                "protein/phenotypes", "protein/fst_vs_founder", "protein/fst_vs_yield", "protein/pca")
for (sub in subfolders) {
  dir.create(file.path(output_base, sub), showWarnings = FALSE, recursive = TRUE)
}

#Custom function to scale traits
scale_to_range <- function(x, new_min, new_max) {
  old_min <- min(x)
  old_max <- max(x)
  scaled <- (x - old_min) / (old_max - old_min)
  return(scaled * (new_max - new_min) + new_min)
}

#Function to calculate basic FST
calc_fst_basic <- function(geno, pop) {
  fst_vals <- apply(geno, 2, function(marker) {
    freq1 <- mean(marker[pop == "pop1"], na.rm = TRUE) / 2
    freq2 <- mean(marker[pop == "pop2"], na.rm = TRUE) / 2
    p_bar <- (freq1 + freq2) / 2
    num <- (freq1 - freq2)^2
    den <- p_bar * (1 - p_bar)
    if (den == 0) return(NA)
    return(num / den)
  })
  return(fst_vals)
}

#Function to run one cycle of selection and analysis
run_cycle <- function(base_pop, founder_genos, founder_label, other_genos, other_label,
                      cycle_num, trait_to_select, trait_name,
                      chr_info, out_prefix) {
  
  #Select top 2 individuals by the specified trait
  selected <- selectInd(base_pop, nInd = 2, use = "pheno", trait = trait_to_select)
  
  #Intermate to create 20 offspring
  offspring <- randCross(selected, nCrosses = 2, nProgeny = 10)  # 2x10 = 20 total
  offspring <- setPheno(offspring)
  
  #Extract and rescale phenotypes
  df <- as.data.frame(pheno(offspring))
  colnames(df) <- c("Yield", "Protein")
  if (trait_name == "yield") {
    df$Yield <- scale_to_range(df$Yield, 75, 95)
    df$Protein <- scale_to_range(df$Protein, 32, 37)
  } else {
    df$Yield <- scale_to_range(df$Yield, 33, 54)
    df$Protein <- scale_to_range(df$Protein, 48, 63)
  }
  df$Strain <- paste0(substr(trait_name, 1, 1), cycle_num, "_", seq_len(nrow(df)))
  
  #Save phenotypes
  write.csv(df, file.path(output_base, trait_name, "phenotypes", paste0("cycle_", cycle_num, ".csv")), row.names = FALSE)
  
  #Extract genotypes
  genos <- pullSnpGeno(offspring)
  rownames(genos) <- df$Strain
  
  #FST vs founder
  geno_all_founder <- rbind(genos, founder_genos)
  labels_founder <- c(rep("pop1", nrow(genos)), rep("pop2", nrow(founder_genos)))
  fst_snps_founder <- calc_fst_basic(geno_all_founder, labels_founder)
  fst_chr_founder <- tapply(fst_snps_founder, chr_info, mean, na.rm = TRUE)
  mean_fst_founder <- mean(fst_chr_founder, na.rm = TRUE)
  
  png(file.path(output_base, trait_name, "fst_vs_founder", paste0("fst_cycle_", cycle_num, ".png")), width = 800, height = 600)
  barplot(fst_chr_founder, main = paste("FST vs Founder - Cycle", cycle_num),
          ylab = "FST", col = "darkorange", las = 2,
          ylim = c(0, max(fst_chr_founder, na.rm = TRUE) + 0.05))
  abline(h = mean_fst_founder, col = "blue", lty = 2)
  text(1, mean_fst_founder + 0.01, paste0("Mean FST = ", round(mean_fst_founder, 3)), col = "blue", pos = 4)
  dev.off()
  
  #FST vs other population
  geno_all_other <- rbind(genos, other_genos)
  labels_other <- c(rep("pop1", nrow(genos)), rep("pop2", nrow(other_genos)))
  fst_snps_other <- calc_fst_basic(geno_all_other, labels_other)
  fst_chr_other <- tapply(fst_snps_other, chr_info, mean, na.rm = TRUE)
  mean_fst_other <- mean(fst_chr_other, na.rm = TRUE)
  
  png(file.path(output_base, trait_name, paste0("fst_vs_", other_label), paste0("fst_cycle_", cycle_num, ".png")), width = 800, height = 600)
  barplot(fst_chr_other, main = paste("FST vs ", toupper(other_label), " - Cycle", cycle_num),
          ylab = "FST", col = "forestgreen", las = 2,
          ylim = c(0, max(fst_chr_other, na.rm = TRUE) + 0.05))
  abline(h = mean_fst_other, col = "blue", lty = 2)
  text(1, mean_fst_other + 0.01, paste0("Mean FST = ", round(mean_fst_other, 3)), col = "blue", pos = 4)
  dev.off()
  
  #PCA (2D)
  genos <- genos[, apply(genos, 2, function(col) var(col) > 0)]
  pca_res <- prcomp(genos, scale. = TRUE)
  pc_df <- as.data.frame(pca_res$x[, 1:2])
  pc_df$Strain <- rownames(genos)
  percent_var <- round((pca_res$sdev[1:2]^2 / sum(pca_res$sdev^2))[1:2] * 100, 2)
  
  p <- ggplot(pc_df, aes(x = PC1, y = PC2)) +
    geom_point(color = "steelblue", size = 2) +
    theme_minimal() +
    labs(title = paste("2D PCA -", toupper(trait_name), "Cycle", cycle_num),
         x = paste0("PC1 (", percent_var[1], "%)"),
         y = paste0("PC2 (", percent_var[2], "%)"))
  
  ggsave(file.path(output_base, trait_name, "pca", paste0("pca_cycle_", cycle_num, ".png")), plot = p, width = 6, height = 5)
  
  #PCA vs Founder
  common_snps_founder <- intersect(colnames(genos), colnames(founder_genos))
  genos_founder_combined <- rbind(genos[, common_snps_founder], founder_genos[, common_snps_founder])
  group_founder <- factor(c(rep("Cycle", nrow(genos)), rep("Founder", nrow(founder_genos))))
  genos_founder_combined <- genos_founder_combined[, apply(genos_founder_combined, 2, function(col) var(col) > 0)]
  
  pca_founder <- prcomp(genos_founder_combined, scale. = TRUE)
  pc_df_founder <- as.data.frame(pca_founder$x[, 1:2])
  pc_df_founder$Group <- group_founder
  var_founder <- round((pca_founder$sdev[1:2]^2 / sum(pca_founder$sdev^2))[1:2] * 100, 2)
  
  p_founder <- ggplot(pc_df_founder, aes(x = PC1, y = PC2, color = Group)) +
    geom_point(size = 2) +
    theme_minimal() +
    scale_color_manual(values = c("Cycle" = "darkorange", "Founder" = "gray40")) +
    labs(title = paste("PCA vs Founder -", toupper(trait_name), "Cycle", cycle_num),
         x = paste0("PC1 (", var_founder[1], "%)"),
         y = paste0("PC2 (", var_founder[2], "%)"))
  
  ggsave(file.path(output_base, trait_name, paste0("pca_vs_founder_cycle_", cycle_num, ".png")), plot = p_founder, width = 6, height = 5)
  
  #PCA vs Other
  common_snps_other <- intersect(colnames(genos), colnames(other_genos))
  genos_other_combined <- rbind(genos[, common_snps_other], other_genos[, common_snps_other])
  group_other <- factor(c(rep("Cycle", nrow(genos)), rep("Other", nrow(other_genos))))
  genos_other_combined <- genos_other_combined[, apply(genos_other_combined, 2, function(col) var(col) > 0)]
  
  pca_other <- prcomp(genos_other_combined, scale. = TRUE)
  pc_df_other <- as.data.frame(pca_other$x[, 1:2])
  pc_df_other$Group <- group_other
  var_other <- round((pca_other$sdev[1:2]^2 / sum(pca_other$sdev^2))[1:2] * 100, 2)
  
  p_other <- ggplot(pc_df_other, aes(x = PC1, y = PC2, color = Group)) +
    geom_point(size = 2) +
    theme_minimal() +
    scale_color_manual(values = c("Cycle" = "darkorange", "Other" = "forestgreen")) +
    labs(title = paste("PCA vs", toupper(other_label), "-", toupper(trait_name), "Cycle", cycle_num),
         x = paste0("PC1 (", var_other[1], "%)"),
         y = paste0("PC2 (", var_other[2], "%)"))
  
  ggsave(file.path(output_base, trait_name, paste0("pca_vs_", other_label, "_cycle_", cycle_num, ".png")), plot = p_other, width = 6, height = 5)
  
  return(offspring)
}

#Run selection cycles for yield and protein populations
chr_info <- rep(1:20, each = 300)

yield_cycles <- list()
yield_base <- pop_yield
for (i in 1:5) {
  yield_base <- run_cycle(
    base_pop = yield_base,
    founder_genos = pullSnpGeno(pop_yield),
    founder_label = "founder",
    other_genos = pullSnpGeno(pop_protein),
    other_label = "protein",
    cycle_num = i,
    trait_to_select = 1,
    trait_name = "yield",
    chr_info = chr_info,
    out_prefix = "yield"
  )
  yield_cycles[[i]] <- yield_base
}

protein_cycles <- list()
protein_base <- pop_protein
for (i in 1:5) {
  protein_base <- run_cycle(
    base_pop = protein_base,
    founder_genos = pullSnpGeno(pop_protein),
    founder_label = "founder",
    other_genos = pullSnpGeno(pop_yield),
    other_label = "yield",
    cycle_num = i,
    trait_to_select = 2,
    trait_name = "protein",
    chr_info = chr_info,
    out_prefix = "protein"
  )
  protein_cycles[[i]] <- protein_base
}

#FST Between Yield and Protein Populations After 5 Cycles

# Re-define the FST function with proper NA and variance checks
calc_fst_basic <- function(geno, pop) {
  fst_vals <- apply(geno, 2, function(marker) {
    group1 <- marker[pop == "yield"]
    group2 <- marker[pop == "protein"]
    
    # Skip SNPs with all NA or no variation
    if (all(is.na(group1)) || all(is.na(group2)) || var(group1, na.rm = TRUE) == 0 || var(group2, na.rm = TRUE) == 0) {
      return(NA)
    }
    
    freq1 <- mean(group1, na.rm = TRUE) / 2
    freq2 <- mean(group2, na.rm = TRUE) / 2
    p_bar <- (freq1 + freq2) / 2
    num <- (freq1 - freq2)^2
    den <- p_bar * (1 - p_bar)
    
    if (is.na(den) || den == 0) return(NA)
    return(num / den)
  })
  return(fst_vals)
}

#Extract 5th-cycle genotypes from each population
geno_yield5 <- pullSnpGeno(yield_cycles[[5]])
geno_protein5 <- pullSnpGeno(protein_cycles[[5]])

#Assign unique row names for tracking
rownames(geno_yield5) <- paste0("y5_", seq_len(nrow(geno_yield5)))
rownames(geno_protein5) <- paste0("p5_", seq_len(nrow(geno_protein5)))

#Combine genotypes and create population labels
geno_all5 <- rbind(geno_yield5, geno_protein5)
pop_labels5 <- c(rep("yield", nrow(geno_yield5)), rep("protein", nrow(geno_protein5)))

#Calculate FST per SNP and summarize
fst_snps5 <- calc_fst_basic(geno_all5, pop_labels5)
fst_by_chr5 <- tapply(fst_snps5, chr_info, mean, na.rm = TRUE)
fst_global5 <- mean(fst_snps5, na.rm = TRUE)

#Print FST results
cat("FST Between Yield and Protein Populations - 5th Cycle:\n")
print(fst_global5)
cat("\n Chromosome-wise FST:\n")
print(fst_by_chr5)

#Save barplot of chromosome-wise FST
png("fst_yield_vs_protein_cycle5.png", width = 800, height = 600)
barplot(fst_by_chr5,
        main = "Chromosome-wise FST (Cycle 5: Yield vs Protein)",
        ylab = "FST",
        xlab = "Chromosome",
        col = "darkred",
        las = 2,
        ylim = c(0, max(fst_by_chr5, na.rm = TRUE) + 0.05))
abline(h = mean(fst_by_chr5, na.rm = TRUE), col = "blue", lty = 2, lwd = 2)
text(x = 1, y = mean(fst_by_chr5, na.rm = TRUE) + 0.01, 
     labels = paste0("Mean FST = ", round(mean(fst_by_chr5, na.rm = TRUE), 3)), 
     col = "blue", pos = 4)
dev.off()


#PCA plots after 5 selection cycles

library(plotly)
library(tidyverse)

#Example: Assuming finalPop_yield and finalPop_protein are Pop objects after 5 cycles
#Replace with your actual variable names
geno_yield <- pullSnpGeno(yield_cycles[[5]])
geno_protein <- pullSnpGeno(protein_cycles[[5]])


#Create labels
labels_yield <- rep("Yield", nrow(geno_yield))
labels_protein <- rep("Protein", nrow(geno_protein))

#Combine
#Remove SNPs with zero variance
geno_combined <- geno_combined[, apply(geno_combined, 2, function(col) var(col, na.rm = TRUE) > 0)]

labels_combined <- c(labels_yield, labels_protein)

#Run PCA
pca_result <- prcomp(geno_combined, center = TRUE, scale. = TRUE)
pca_df <- as.data.frame(pca_result$x[, 1:3])  # First 3 PCs
pca_df$Population <- labels_combined

#Variance explained
var_explained <- round(100 * summary(pca_result)$importance[2, 1:3], 2)

#Plot with plotly
fig <- plot_ly(
  data = pca_df,
  x = ~PC1, y = ~PC2, z = ~PC3,
  color = ~Population,
  colors = c("darkorange", "darkgreen"),
  type = 'scatter3d',
  mode = 'markers',
  marker = list(size = 5)
) %>%
  layout(
    scene = list(
      xaxis = list(title = paste0("PC1 (", var_explained[1], "%)")),
      yaxis = list(title = paste0("PC2 (", var_explained[2], "%)")),
      zaxis = list(title = paste0("PC3 (", var_explained[3], "%)"))
    ),
    title = "3D PCA of Cycle 5 Yield vs Protein Populations"
  )

fig

#----------------#
#-----PART 2-----#
#----------------#

setwd("C:\\Users\\arthu\\Desktop\\final exam jin liang analyses")
rm(list = ls())


library(AlphaSimR)
library(ggplot2)
library(dplyr)
library(tidyr)
library(plotly)
library(sommer)

#founder population
set.seed(123)
founderPop <- runMacs(nInd = 40, nChr = 20, segSites = 6000, species = "GENERIC")

#simulation parameters with correlated traits
SP <- SimParam$new(founderPop)
SP$addTraitA(
  nQtlPerChr = 30,
  mean = c(0, 0),
  var = c(1, 1),
  corA = matrix(c(1, -0.45, -0.45, 1), 2)
)
SP$setVarE(h2 = c(0.45, 0.70))

#SNP chip
SP$addSnpChip(nSnpPerChr = 300)

#generate populations
pop_all <- newPop(founderPop)
pop_yield <- pop_all[1:20]
pop_protein <- pop_all[21:40]

#simulate phenotypes
pop_yield <- setPheno(pop_yield)
pop_protein <- setPheno(pop_protein)

#phenotype values
scale_to_range <- function(x, new_min, new_max) {
  old_min <- min(x)
  old_max <- max(x)
  scaled <- (x - old_min) / (old_max - old_min)
  return(scaled * (new_max - new_min) + new_min)
}

df_yield <- as.data.frame(pheno(pop_yield))
colnames(df_yield) <- c("Yield", "Protein")
df_yield$Yield <- scale_to_range(df_yield$Yield, 75, 95)
df_yield$Protein <- scale_to_range(df_yield$Protein, 32, 37)

df_protein <- as.data.frame(pheno(pop_protein))
colnames(df_protein) <- c("Yield", "Protein")
df_protein$Yield <- scale_to_range(df_protein$Yield, 33, 54)
df_protein$Protein <- scale_to_range(df_protein$Protein, 48, 63)

df_yield$Strain <- paste0("y", seq_len(nrow(df_yield)))
df_protein$Strain <- paste0("p", seq_len(nrow(df_protein)))

geno_yield <- pullSnpGeno(pop_yield)
geno_protein <- pullSnpGeno(pop_protein)

rownames(geno_yield) <- df_yield$Strain
rownames(geno_protein) <- df_protein$Strain

head(df_yield)
head(df_protein)

#Founder Simulation + Divergent Selection

set.seed(123)
founderPop <- runMacs(nInd = 40, nChr = 20, segSites = 6000, species = "GENERIC")

SP <- SimParam$new(founderPop)
SP$addTraitA(nQtlPerChr = 30, mean = c(0, 0), var = c(1, 1),
             corA = matrix(c(1, -0.45, -0.45, 1), 2))
SP$setVarE(h2 = c(0.45, 0.70))
SP$addSnpChip(nSnpPerChr = 300)

pop_all <- newPop(founderPop)
pop_yield <- pop_all[1:20]
pop_protein <- pop_all[21:40]

pop_yield <- setPheno(pop_yield)
pop_protein <- setPheno(pop_protein)

yield_cycles <- list()
protein_cycles <- list()

for (i in 1:5) {
  pop_yield <- selectInd(pop_yield, 2, use = "pheno", trait = 1)
  pop_yield <- randCross(pop_yield, 2, 10)
  pop_yield <- setPheno(pop_yield)
  yield_cycles[[i]] <- pop_yield
  
  pop_protein <- selectInd(pop_protein, 2, use = "pheno", trait = 2)
  pop_protein <- randCross(pop_protein, 2, 10)
  pop_protein <- setPheno(pop_protein)
  protein_cycles[[i]] <- pop_protein
}

#Phenotypic Selection

make_diallel <- function(parents) {
  combos <- combn(1:length(parents), 2)
  lapply(1:ncol(combos), function(i) {
    randCross2(parents[[combos[1, i]]], parents[[combos[2, i]]], 100, simParam = SP)
  })
}

#top 5 individuals
top5_yield <- selectInd(yield_cycles[[5]], 5, use = "pheno", trait = 1)
top5_protein <- selectInd(protein_cycles[[5]], 5, use = "pheno", trait = 2)

split_individuals <- function(pop) {
  lapply(1:pop@nInd, function(i) pop[i])
}

#top5 as individual parents
top5_yield_list <- split_individuals(top5_yield)
top5_protein_list <- split_individuals(top5_protein)

#crosses (non-reciprocal) to generate 10 families
make_diallel <- function(parents) {
  combos <- combn(1:length(parents), 2)
  crosses <- list()
  for (i in 1:ncol(combos)) {
    p1 <- parents[[combos[1, i]]]
    p2 <- parents[[combos[2, i]]]
    crosses[[i]] <- randCross2(females = p1, males = p2, nCrosses = 1, nProgeny = 100, simParam = SP)
  }
  return(crosses)
}

#crossing
pop_yield <- Reduce(c, make_diallel(top5_yield_list))
pop_protein <- Reduce(c, make_diallel(top5_protein_list))

cycle_means_yield <- list()
cycle_means_protein <- list()

for (cycle in 1:10) {
  pop_yield <- setPheno(pop_yield)
  cycle_means_yield[[cycle]] <- pheno(pop_yield)[, 1]
  pop_yield <- randCross(selectInd(pop_yield, 5, use = "pheno", trait = 1), 5, 200)
  
  pop_protein <- setPheno(pop_protein)
  cycle_means_protein[[cycle]] <- pheno(pop_protein)[, 2]
  pop_protein <- randCross(selectInd(pop_protein, 5, use = "pheno", trait = 2), 5, 200)
}

phen_combined <- bind_rows(
  lapply(1:10, function(i) data.frame(Cycle = i, Value = cycle_means_yield[[i]], Trait = "Yield")),
  lapply(1:10, function(i) data.frame(Cycle = i, Value = cycle_means_protein[[i]], Trait = "Protein"))
)
write.csv(phen_combined, "phenotypic_selection_means_per_cycle.csv", row.names = FALSE)

#phenotypic values
phen_scaled <- phen_combined %>%
  group_by(Trait) %>%
  mutate(ScaledValue = scale(Value)) %>%
  ungroup()

#Plot

ggplot(phen_scaled, aes(x = Cycle, y = ScaledValue, color = Trait)) +
  geom_smooth(method = "loess", se = FALSE, span = 0.75, size = 1.2) +
  theme_minimal() +
  scale_x_continuous(breaks = 1:10) +
  labs(
    y = "Selection Gain",
    x = "Cycle"
  )

ggsave("phenotypic_gain_loess.png", dpi = 300, width = 8, height = 5)

#GBLUP / RRBLUP

geno_progress_y <- list()
geno_progress_p <- list()

for (cycle in 1:10) {
  message(paste("Starting cycle", cycle))
  
#YIELD
  
  pop_yield <- setPheno(pop_yield)
  geno_y <- pullSnpGeno(pop_yield)
  rownames(geno_y) <- pop_yield@id
  
  geno_y <- geno_y[!duplicated(rownames(geno_y)), ]
  geno_y <- geno_y[complete.cases(geno_y), ]
  
  pheno_y <- data.frame(ID = pop_yield@id, y = as.numeric(pheno(pop_yield)[, 1]))
  pheno_y <- pheno_y[pheno_y$ID %in% rownames(geno_y), ]
  geno_y <- geno_y[pheno_y$ID, ]  # align rows
  
  y_vec <- pheno_y$y
  names(y_vec) <- pheno_y$ID
  
  train_ids <- sample(names(y_vec), 250)
  y_train <- y_vec[train_ids]
  M_train <- geno_y[train_ids, , drop = FALSE]
  
  rrblup_y <- tryCatch({
    mixed.solve(y = y_train, Z = M_train)
  }, error = function(e) {
    warning("Yield RR-BLUP failed: ", e$message)
    return(NULL)
  })
  
  if (!is.null(rrblup_y)) {
    # Predict all individuals
    gebv_all_y <- geno_y %*% rrblup_y$u
    gebv_y_df <- data.frame(ID = rownames(geno_y), GEBV = gebv_all_y[,1])
    
    geno_progress_y[[cycle]] <- gebv_y_df$GEBV
    top5_ids_y <- gebv_y_df %>%
      arrange(desc(GEBV)) %>%
      slice(1:5) %>%
      pull(ID)
    
    pop_yield <- randCross(pop_yield[top5_ids_y], 5, 200)
  } else {
    warning("Skipping YIELD selection for cycle ", cycle, " due to GEBV extraction error.")
  }
  
#PROTEIN - RR-BLUP

    pop_protein <- setPheno(pop_protein)
  geno_p <- pullSnpGeno(pop_protein)
  rownames(geno_p) <- pop_protein@id
  
  geno_p <- geno_p[!duplicated(rownames(geno_p)), ]
  geno_p <- geno_p[complete.cases(geno_p), ]
  
  pheno_p <- data.frame(ID = pop_protein@id, p = as.numeric(pheno(pop_protein)[, 2]))
  pheno_p <- pheno_p[pheno_p$ID %in% rownames(geno_p), ]
  geno_p <- geno_p[pheno_p$ID, ]  # align rows
  
  p_vec <- pheno_p$p
  names(p_vec) <- pheno_p$ID
  
  train_ids <- sample(names(p_vec), 250)
  p_train <- p_vec[train_ids]
  M_train <- geno_p[train_ids, , drop = FALSE]
  
  rrblup_p <- tryCatch({
    mixed.solve(y = p_train, Z = M_train)
  }, error = function(e) {
    warning("Protein RR-BLUP failed: ", e$message)
    return(NULL)
  })
  
  if (!is.null(rrblup_p)) {
    gebv_all_p <- geno_p %*% rrblup_p$u
    gebv_p_df <- data.frame(ID = rownames(geno_p), GEBV = gebv_all_p[,1])
    
    geno_progress_p[[cycle]] <- gebv_p_df$GEBV
    top5_ids_p <- gebv_p_df %>%
      arrange(desc(GEBV)) %>%
      slice(1:5) %>%
      pull(ID)
    
    pop_protein <- randCross(pop_protein[top5_ids_p], 5, 200)
  } else {
    warning("Skipping PROTEIN selection for cycle ", cycle, " due to GEBV extraction error.")
  }
}

geno_combined <- bind_rows(
  lapply(seq_along(geno_progress_y), function(i) {
    data.frame(Cycle = i, GEBV = geno_progress_y[[i]], Trait = "Yield")
  }),
  lapply(seq_along(geno_progress_p), function(i) {
    data.frame(Cycle = i, GEBV = geno_progress_p[[i]], Trait = "Protein")
  })
)

geno_scaled <- geno_combined %>%
  group_by(Trait) %>%
  mutate(ScaledGEBV = scale(GEBV)[, 1]) %>%
  ungroup()

Plot
Yield plot
geno_scaled %>%
  filter(Trait == "Yield") %>%
  group_by(Cycle) %>%
  summarize(MeanGEBV = mean(ScaledGEBV, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(x = Cycle, y = MeanGEBV)) +
  geom_smooth(method = "loess", span = 0.75, se = FALSE, color = "darkgreen", size = 1.2) +
  geom_point(color = "darkgreen", size = 2) +
  theme_minimal() +
  labs(title = "",
       y = "Selection Gains", x = "Cycle") +
  scale_x_continuous(breaks = 1:10)+
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

geno_scaled %>%
  filter(Trait == "Protein") %>%
  group_by(Cycle) %>%
  summarize(MeanGEBV = mean(ScaledGEBV, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(x = Cycle, y = MeanGEBV)) +
  geom_smooth(method = "loess", span = 0.75, se = FALSE, color = "darkgreen", size = 1.2) +
  geom_point(color = "darkgreen", size = 2) +
  theme_minimal() +
  labs(title = "",
       y = "Selection Gains", x = "Cycle") +
  scale_x_continuous(breaks = 1:10)+
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

