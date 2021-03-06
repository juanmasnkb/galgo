#' createFolds splits the data into k groups to perform cross-validation
#'
#' @param y a vector of outcomes
#' @param k an integer for the number of folds
#' @param list logical - should the results be in a list (TRUE) or in a vector
#' @param returnTrain a logical. When true, the values returned are the sample positions correspondingto the data used during training. This argument only works in conjunction withlist = TRUE
#'
#' @return if list=TRUE, it returns a list with k elements were each element of the list has the position of the outcomes included in said fold, if list=FALSE the function returns a vector where each outcome is assigned to a given fold from 1 to k
#' @export
#'
#' @examples
#' y= rnorm(100,5,2) # A vector of outcomes
#' k= 5 #Number of folds
#' createFolds(y,k=k,list=TRUE)

createFolds <- function (y, k = 10, list = TRUE, returnTrain = FALSE)
{
  if (class(y)[1] == "Surv")
    y <- y[, "time"]
  if (is.numeric(y)) {
    cuts <- floor(length(y)/k)
    if (cuts < 2)
      cuts <- 2
    if (cuts > 5)
      cuts <- 5
    breaks <- unique(stats::quantile(y, probs = seq(0, 1, length = cuts)))
    y <- cut(y, breaks, include.lowest = TRUE)
  }
  if (k < length(y)) {
    y <- factor(as.character(y))
    numInClass <- table(y)
    foldVector <- vector(mode = "integer", length(y))
    for (i in 1:length(numInClass)) {
      min_reps <- numInClass[i]%/%k
      if (min_reps > 0) {
        spares <- numInClass[i]%%k
        seqVector <- rep(1:k, min_reps)
        if (spares > 0)
          seqVector <- c(seqVector, sample(1:k, spares))
        foldVector[which(y == names(numInClass)[i])] <- sample(seqVector)
      }
      else {
        foldVector[which(y == names(numInClass)[i])] <- sample(1:k,
                                                               size = numInClass[i])
      }
    }
  }
  else foldVector <- seq(along = y)
  if (list) {
    out <- split(seq(along = y), foldVector)
    names(out) <- paste("Fold", gsub(" ", "0", format(seq(along = out))),
                        sep = "")
    if (returnTrain)
      out <- lapply(out, function(data, y) y[-data], y = seq(along = y))
  }
  else out <- foldVector
  out
}


#' Harmonic mean
#' The harmonic mean can be expressed as the reciprocal of the arithmetic mean of the reciprocals of a given set of observations.  Since the harmonic mean of a list of numbers tends strongly toward the least elements of the list, it tends (compared to the arithmetic mean) to mitigate the impact of large outliers and aggravate the impact of small ones.
#'
#'
#' @param a vector of numbers
#'
#' @return the harmonic mean of the values in a is computed, as a numeric vector of length one
#' @export
#'
#' @examples
#' x= rnorm(5,2,1) #five random numbers from the normal distribution
#' x= c(x,20) #add outlier
#' hmean(x)

hmean <- function(a) {
  1 / mean(1 / a)
}

#' Restricted Mean Survival distance between groups
#'
#' @param x A numeric vector of length > 1
#'
#' @return A numeric vector of length 1. The function computes the Harmonic mean of the differences between consecutive groups multiplied by the number of comparisons
#' This function is used inside 'fitness' function.
#' @export
#'
#' @examples
#' V <- c(4.5,3,7,11)
#' cDist(V)
cDist <- function(x) {
  d <- x[order(x)]
  l <- length(d) - 1
  c <- c(0, 1)
  dif <- as.numeric()
  for (i in 1:l) {
    dif <- c(dif, diff(d[c + i]))
  }
  return(hmean(dif) * l)
}




#' Survival fitness function using the Restricted Mean Survival Time (RMST) of each group
#'
#' @param OS a survival object with survival data of the patients evaluated
#' @param clustclass a numeric vector with the group label for each patient
#' @param period a number representing the period of time to evaluate in the RMST calculation
#'
#' @return The function computes the Harmonic mean of the differences between Restricted Mean Survival Time (RMST) of consecutive survival curves multiplied by the number of comparisons
#' Restricted Mean Survival Time: https://www.bmj.com/content/357/bmj.j2250
#' @export
#'
#' @examples
#' rna_luad<-use_rna_luad()
#' clinical <- rna_luad$clinical
#' OS <- survival::Surv(time=clinical$time,event=clinical$status)
#' fitness(OS,clustclass= clinical$Wilk.Subtype, 1825)

fitness <- function(OS, clustclass,period) {
  score <- tryCatch(
    {
      t <- survival:::survmean(survival::survfit(OS ~ clustclass), rmean = period)[[1]][, "*rmean"] # This function calculates the RMST (comes from package survival)
      cDist(t)
    },
    error = function(e) {
      return(0)
    }
  ) # If cDist cannot be calculated, the difference is set to 0 (no difference between curves)
  return(score)
}

## Helpers Functions to vectorize crossvalidation

#' Title
#'
#' @param flds
#' @param Data
#'
#' @return
#' @export
#'
#' @examples
ArrayTrain <- function(flds, Data) {
  trainData <- Data[, -flds]
}

#' Title
#'
#' @param flds
#' @param Data
#'
#' @return
#' @export
#'
#' @examples
ArrayTest <- function(flds, Data) {
  testData <- Data[, flds]
}


#' Title
#'
#' @param flds
#' @param D
#'
#' @return
#' @export
#'
#' @examples
subDist <- function(flds, D) {
    sub <- subset(D, -flds)
}

#' Title
#'
#' @param C
#'
#' @return
#' @export
#'
#' @examples
alloc2 <- function(C) {
  Ct <- t(C)
  ord <- matchingR::galeShapley.marriageMarket(C, Ct)
  return(ord$engagements)
}


#' Title
#'
#' @param C
#' @param ord
#'
#' @return
#' @export
#'
#' @examples
reord <- function(C, ord) {
  C <- C[, ord]
}

#' Title
#'
#'crossvalidation function based on: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3105299/
#' Data is the expression matrix
#' flds is a list with the indexes to partition the data in n different folds
#' indv is the solution to test, namely, a binary vector to subset the genes to test
#' The function returns two fitness: fit1 (the mean silhouette) and fit2 (the ad-hoc function to estimate the differences between curves)

#' @param Data
#' @param flds
#' @param indv
#' @param k
#' @param OS
#' @param distance
#' @param nCV
#' @param period
#'
#' @return
#' @export
#'
#' @examples
crossvalidation <- function(Data, flds, indv, k, OS, distance,nCV,period) {
  Data <- Data[indv, ]
  D <- distance(Data)
  TrainA <- sapply(flds, ArrayTrain, Data = Data, simplify = FALSE)
  TestA <- sapply(flds, ArrayTest, Data = Data, simplify = FALSE)
  SUB <- sapply(flds, subDist, D = D, simplify = FALSE)
  hc <- sapply(SUB, cluster_algorithm, k = k)
  C <- mapply(kcentroid, TrainA, hc, SIMPLIFY = FALSE)
  CentrCor <- mapply(stats::cor, C[1], C[2:nCV], SIMPLIFY = FALSE)
  Cord <- sapply(CentrCor, alloc2, simplify = FALSE)
  Cord <- append(list(as.matrix(1:k, ncol = 1)), Cord, 1)
  C <- mapply(reord, C, Cord, SIMPLIFY = FALSE)
  CLASS <- mapply(classify, TestA, C, SIMPLIFY = FALSE)
  # t1=Sys.time();for(i in 1:10){CLASS=mapply(classify2,TestA,C,SIMPLIFY=FALSE)};t2=Sys.time();t2-t1
  clustclass <- unlist(CLASS)
  clustclass <- clustclass[order(as.vector(unlist(flds)))]
  fit1 <- mean(cluster::silhouette(clustclass, D)[, 3])
  fit2 <- fitness(OS, clustclass,period)

  return(c(fit1, fit2))
}

#' Title
#' Minimum number of genes to use in a solution (A constraint for the algorithm)
#'
#' @param x
#' @param chrom_length
#'
#' @return
#' @export
#'
#' @examples
minGenes <- function(x,chrom_length) {
  sum(x) >= 10 & sum(x) < chrom_length
}

#' Title
#'
#' http://ictactjournals.in/paper/IJSC_V6_I1_paper_4_pp_1083_1092.pdf
#' Multiple point crossover
#' a and b is solution 1 and 2 respectively (binary vectors)
#' n is the number of cut points
#'
#' @param a
#' @param b
#' @param n
#'
#' @return
#' @export
#'
#' @examples
kcrossover <- function(a, b, n) {
  if (length(a) != length(b)) {
    stop("vectors of unequal length")
  }
  l <- length(a)
  if (n >= (length(a) - 1)) {
    stop("number of cut points bigger than possible sites")
  }
  points <- sample(2:(l - 1), n, replace = FALSE)
  to <- c(points[order(points)][-n], l)
  from <- c(1, to[-length(to)] + 1)
  cutpoints <- list()
  for (i in 1:n) {
    cutpoints[[i]] <- seq(from[i], to[i])
  }
  achild <- as.numeric()
  bchild <- as.numeric()
  for (i in 1:n) {
    if (i %% 2 == 0) {
      achild <- c(achild, a[cutpoints[[i]]])
      bchild <- c(bchild, b[cutpoints[[i]]])
    } else {
      achild <- c(achild, b[cutpoints[[i]]])
      bchild <- c(bchild, a[cutpoints[[i]]])
    }
  }
  return(list(achild, bchild))
}

#' Title
#' Uniformcrossover
#'
#' @param a
#' @param b
#'
#' @return
#' @export
#'
#' @examples
ucrossover <- function(a, b) {
  if (length(a) != length(b)) {
    stop("vectors of unequal length")
  }
  l <- length(a)
  points <- as.logical(rbinom(l, 1, prob = runif(1)))
  achild <- numeric(l)
  achild[points] <- a[points]
  achild[!points] <- b[!points]
  bchild <- numeric(l)
  bchild[points] <- b[points]
  bchild[!points] <- a[!points]
  return(list(achild, bchild))
}

#' Title
#' Asymmetric mutation operator:
#' Analysis of an Asymmetric Mutation Operator; Jansen et al.
#'
#' @param x
#'
#' @return
#' @export
#'
#' @examples
asMut <- function(x) {
  chrom_length <- length(x)
  res <- x
  Active <- sum(x)
  Deactive <- chrom_length - Active
  mutrate1 <- 1 / Active
  mutrate2 <- 1 / Deactive
  mutpoint1 <- sample(c(1, 0), Deactive, prob = c(mutrate2, 1 - mutrate2), replace = TRUE)
  res[x == 0] <- abs(x[x == 0] - mutpoint1)

  mutpoint2 <- sample(c(1, 0), Active, prob = c(mutrate1, 1 - mutrate1), replace = TRUE)
  res[x == 1] <- abs(x[x == 1] - mutpoint2)

  return(res)
}


#' Title
#' Offspring creation
#'
#' @param X1
#' @param chrom_length
#' @param population
#' @param TournamentSize
#'
#' @return
#' @export
#'
#' @examples
offspring <- function(X1, chrom_length, population, TournamentSize) {
  New <- matrix(NA, ncol = chrom_length, nrow = population) # Create empty matrix to add new individuals
  NewK <- matrix(NA, nrow = 1, ncol = population) # same for cluster chromosome

  matingPool <- nsga2R::tournamentSelection(X1, population, TournamentSize) # Use tournament selection, to select parents that will give offspring

  count <- 0 # Count how many offsprings are still needed to reach the original population size
  while (anyNA(New)) {
    count <- count + 1
    ## a.Select a pair of parent chromosomes from the matingPool
    Pair <- sample(1:nrow(matingPool), 2, replace = F)


    ## b.With probability pc (the "crossover probability" or "crossover rate"), cross over the pair at a n randomly chosen points (with probability p, chosen randomly from uniform distribution) to form two offspring. If no crossover takes place, exact copies of their respective parents are pass to the next generation.

    Cp <- 1 # with elitism there is no need to add a crossover probability
    if (sample(c(1, 0), 1, prob  = c(Cp, 1 - Cp)) == 1) { #
      # multiple point crossingover
      offspring <- ucrossover(matingPool[Pair[1], 1:chrom_length], matingPool[Pair[2], 1:chrom_length])
      off1 <- offspring[[1]]
      off2 <- offspring[[2]]
    } else {
      off1 <- matingPool[Pair[1], 1:chrom_length]
      off2 <- matingPool[Pair[2], 1:chrom_length]
    }

    ## c.Mutate the two offspring at each locus with probability Mp (the mutation probability or mutation rate),
    # and place the resulting chromosomes in the new population.
    # since the results are sparse strings, cosine similarity is more adequate
    # Mutation by asymmetric mutation: Analysis of an Asymmetric Mutation Operator; Jansen et al.

    Mp <- cosine(matingPool[Pair[1], 1:chrom_length], matingPool[Pair[2], 1:chrom_length])

    if (sample(c(1, 0), 1, prob = c(Mp, 1 - Mp)) == 1) {
      off1 <- asMut(off1)
    }
    if (sample(c(1, 0), 1, prob = c(Mp, 1 - Mp)) == 1) {
      off2 <- asMut(off2)
    }

    # Mutation for k (number of partitions)

    p <- 0.3
    probs <- rep((1 - p) / 9, 9)
    k1 <- matingPool[Pair[1], "k"]
    k2 <- matingPool[Pair[2], "k"]
    probs[k1 - 1] <- probs[k1 - 1] + p / 2
    probs[k2 - 1] <- probs[k2 - 1] + p / 2
    offk1 <- sample(2:10, 1, prob = probs)
    offk2 <- sample(2:10, 1, prob = probs)

    # Add offsprings to new generation
    New[count, ] <- off1
    New[count + 1, ] <- off2
    NewK[, count] <- offk1
    NewK[, count + 1] <- offk2
  }
  return(list(New = New, NewK = NewK))
}

#' Title
#'Penalize Fitness2 function according the number of genes
#' @param x
#'
#' @return
#' @export
#'
#' @examples
pen <- function(x) {
  1 / (1 + (x / 500)^2)
}


#' Title
#' Base callback function
#' Save  population
#'
#' @param directory
#' @param prefix
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return an objet of class galgo
#' @export
#'
#' @examples
base_save_pop_callback <- function(directory="results/",prefix,generation,pop_pool,pareto,prob_matrix,current_time){
  if (!dir.exists(directory))
    dir.create(directory)
  colnames(pop_pool)[1:(ncol(pop_pool) - 5)] <- rownames(prob_matrix)
  output <- list(Solutions = pop_pool, ParetoFront = pareto)
  filename <- paste0(directory,prefix, ".rda")
  save(file = filename, output)
  class(output)<- "galgo.Obj"
  return(output)
}

#' Title
#' Save partial population (every 2 generations)
#'
#' @param directory
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
base_save_pop_partial_callback <- function(directory="results/",generation,pop_pool,pareto,prob_matrix,current_time){
  if (!dir.exists(directory))
      dir.create(directory)
  if (generation %% 2 == 0){
    base_save_pop_callback(directory,prefix=generation,generation,pop_pool,pareto,prob_matrix,current_time)
  }

}

#' Title
#'
#' @param directory
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
base_save_pop_final_callback <- function(directory="results/",generation,pop_pool,pareto,prob_matrix,current_time){
  if (!dir.exists(directory))
    dir.create(directory)
  #environment(base_save_pop_callback)<-environment()
  output<- base_save_pop_callback(directory,prefix="final",generation,pop_pool,pareto,prob_matrix,current_time)
  print(paste0("final population saved in final.rda"))
  class(output)<- "galgo.Obj"
  return(output)
}

#' Title
#' Print basic info per generation
#'
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
base_report_callback <- function(generation,pop_pool,pareto,prob_matrix,current_time){
  chrom_length <- nrow(prob_matrix)
  print(paste0("Generation ", generation, " Non-dominated solutions:"))
  print(pop_pool[pop_pool[, "rnkIndex"] == 1, (chrom_length + 1):(chrom_length + 5)])
  #print(Sys.time()- start_time)
}

#' Title
#'
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
no_report_callback <- function(generation,pop_pool,pareto,prob_matrix,current_time){
  if(generation%%5==0)
    cat("*")
  else
    cat(".")
}

#' Title
#'
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
base_start_gen_callback <- function(generation,pop_pool,pareto,prob_matrix,current_time){
  #start_time <- Sys.time()
}

#' Title
#'
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
base_end_gen_callback <- function(generation,pop_pool,pareto,prob_matrix,current_time){
  #print(Sys.time()- start_time)
}

#' Title
#'
#' @param generation
#' @param pop_pool
#' @param pareto
#' @param prob_matrix
#' @param current_time
#'
#' @return
#' @export
#'
#' @examples
default_callback <- function(generation,pop_pool,pareto,prob_matrix,current_time){

}

#' Title
#' CONVERT OUTPUT TO LIST
#'
#' @param output
#'
#' @return
#' @export
#'
#' @examples

toList <- function(output) {
  if (!methods::is(output, "galgo.Obj")) {
    stop("object must be of class 'galgo.Obj'")
  }
  OUTPUT <- list()
  Genes <- colnames(output$Solutions)[1:(ncol(output$Solutions) - 5)]
  for (i in 1:nrow(output$Solutions)) {
    Sol <- paste("Solution", i, sep = ".")
    OUTPUT[[Sol]] <- list()
    OUTPUT[[Sol]][["Genes"]] <- Genes[as.logical(output$Solutions[i, 1:length(Genes)])]
    OUTPUT[[Sol]]["k"] <- output$Solutions[i, "k"]
    OUTPUT[[Sol]]["SC.Fit"] <- output$Solutions[i, length(Genes) + 2]
    OUTPUT[[Sol]]["Surv.Fit"] <- output$Solutions[i, length(Genes) + 3]
    OUTPUT[[Sol]]["rank"] <- output$Solutions[i, "rnkIndex"]
    OUTPUT[[Sol]]["CrowD"] <- output$Solutions[i, "CrowD"]
  }
  return(OUTPUT)
}

#' Title
#' CONVERT OUTPUT TO DATA.FRAME
#' @param output
#'
#' @return
#' @export
#'
#' @examples
toDataFrame <- function(output) {
    if (!methods::is(output, "galgo.Obj")) {
        stop("object must be of class 'galgo.Obj'")
    }
    Genes <- colnames(output$Solutions)[1:(ncol(output$Solutions) - 5)]
    ListGenes <- list()
    for (i in 1:nrow(output$Solutions)) {
        ListGenes[[i]] <- list()
        ListGenes[[i]] <- Genes[as.logical(output$Solutions[i, 1:length(Genes)])]
    }
    
    OUTPUT <- data.frame(Genes = I(ListGenes), k = output$Solutions[, "k"], SC.Fit = output$Solutions[, ncol(output$Solutions) - 3], Surv.Fit = output$Solutions[, ncol(output$Solutions) - 2], Rank = output$Solutions[, "rnkIndex"], CrowD = output$Solutions[, "CrowD"])
  rownames(OUTPUT) <- paste("Solutions", 1:nrow(output$Solutions) ,sep=".")
  return(OUTPUT)
}

#' Galgo main function
#'
#' 'galgo' accepts an expression matrix and a survival object to find robust gene expression signatures related to a given outcome
#'                   
#' @param population  a number indicating the number of solutions in the population of solutions that will be evolved 
#' @param generations a number indicating the number of iterations of the galgo algorithm
#' @param nCV number of cross-validation sets
#' @param usegpu logical default FALSE, set to TRUE if you wish to use gpu computing (gpuR package must be properly installed and loaded)
#' @param distancetype character, it can be "pearson" (centered pearson), "uncentered" (uncentered pearson), "spearman" or "euclidean"
#' @param TournamentSize a number indicating the size of the tournaments for the selection procedure
#' @param period a number indicating the outcome period to evaluate the RMST
#' @param OS a survival object (see 'Surv' function from the 'survival' package)
#' @param prob_matrix a matrix or data.frame. Must be an expression matrix with features in rows and samples in columns
#' @param res_dir a character indicating where to save the intermediate and final output of the algorithm
#' @param save_pop_partial_callback optional callback function between iterations
#' @param save_pop_final_callback optional callback function for the last iteration
#' @param report_callback optional callback function
#' @param start_gen_callback optional callback function for the beginning of the run
#' @param end_gen_callback optional callback function for the end of the run
#' @param verbose ?
#'
#' @return an object of type 'galgo.Obj' that corresponds to a list with the elements $Solutions and $ParetoFront. $Solutions is a l x (n + 5) matrix where n is the number of features evaluated and l is the number of solutions obtained.
#' The submatrix l x n is a binary matrix where each row represents the chromosome of an evolved solution from the solution population where each feature can be present (1) or absent (0). Column n +1 represent the  k number of clusters for each solutions. Column n+2 to n+5 shows the SC Fitness and Survival Fitness values, the solution rank and the crowding distance of the solution in the final pareto front respectevely.
#' For easier interpretation of the 'galgo.Obj', the output can be reshaped using the 'toList' and 'toDataFrame' functions     
#'                    
#' @export
#'
#' @examples
#' rna_luad<-use_rna_luad()
#'
#' prm <- rna_luad$prm 
#' clinical <- rna_luad$clinical
#' OS <- survival::Surv(time=clinical$time,event=clinical$status)
#' output <- galgo(generations = 10, population = 30,prob_matrix = prm, OS=OS)
#' outputDF <- toDataFrame(output)
    
                    
                    
galgo <- function(population = 30, # Number of individuals to evaluate
                       generations = 2, # Number of generations
                       nCV = 5, # Number of crossvalidations for function "crossvalidation"
                       usegpu = FALSE, # to use gpuR
                       distancetype = "pearson", # Options are: "pearson","uncentered","spearman","euclidean"
                       TournamentSize = 2,
                       period = 1825,
                       OS, #OS=Surv(time=clinical$time,event=clinical$status)
                       prob_matrix,
                       res_dir="results/",
                       save_pop_partial_callback=base_save_pop_partial_callback,
                       save_pop_final_callback=base_save_pop_final_callback,
                       report_callback=base_report_callback,
                       start_gen_callback=base_start_gen_callback,
                       end_gen_callback=base_end_gen_callback,
                       verbose=2
) {

  if (verbose == 0){
    report_callback = default_callback
    start_gen_callback = default_callback
    end_gen_callback = default_callback
  }

  if (verbose == 1){
    report_callback = no_report_callback
    start_gen_callback = default_callback
    end_gen_callback = default_callback

  }


  # Support for parallel computing.
  cluster <- parallel::makeCluster(parallel::detectCores() - 1) # convention to leave 1 core for OS
  doParallel::registerDoParallel(cluster)
  calculate_distance <- select_distance(distancetype, usegpu)
  # Empty list to save the solutions.
  PARETO <- list()
  chrom_length <- nrow(prob_matrix)
  # 1. Create random population of solutions.

  # Creating random clusters from 2-10.
  Nclust <- sample(2:10, population, replace = TRUE)

  # Matrix with random TRUE false with uniform distribution, representing solutions to test.
  X <- matrix(NA, nrow = population, ncol = chrom_length)
  for (i in 1:population) {
    prob <- runif(1, 0, 1)
    X[i, ] <- sample(c(1, 0), chrom_length, replace = T, prob = c(prob, 1 - prob))
  }

  ##### Main loop.
  for (g in 1:generations) {
    # Output for the generation callback
    callback_data <- list()
    environment(start_gen_callback)<-environment()
    start_gen_callback()

    start_time <- Sys.time() # Measures generation time

    # 2.Calculate the fitness f(x) of each chromosome x in the population.
    Fit1 <- apply(X, 1, minGenes,chrom_length = chrom_length) # Apply constraints (min 10 genes per solution). #TODO: Check chrom_length parameter
    #Fit1 <- apply(X, 1, minGenes) # Apply constraints (min 10 genes per solution). #TODO: Check chrom_length parameter
    X <- X[Fit1, ]
    X <- apply(X, 2, as.logical)
    n <- nrow(X)
    Nclust <- Nclust[Fit1]

    k <- Nclust

    flds <- createFolds(1:ncol(prob_matrix), k = nCV)

    `%dopar%` <- foreach::`%dopar%`
    `%do%` <- foreach::`%do%`
    reqpkgs <- c("cluster","cba", "survival", "matchingR","galgoR")
    #reqpkgs <- c("cluster","cba", "survival", "matchingR")
    if (usegpu == TRUE ){
      # TODO: add validation for opencl machine. if not fallback to CPU.
      reqpkgs <- c(reqpkgs,"gpuR")
    }


    # Calculate Fitnes 1 (silhouette) and 2 (Survival differences).
    Fit2 <- foreach::foreach(i = 1:nrow(X), .packages = reqpkgs, .combine = rbind) %dopar% {
      #devtools::load_all() # required for package devel
      crossvalidation(prob_matrix, flds, X[i, ], k[i], OS = OS, distance = calculate_distance, nCV, period)
    }

    # Penalization of SC by number of genes.
    Fit2[, 1] <- (Fit2[, 1] * pen(rowSums(X)))

    if (g == 1) {
      PARETO[[g]] <- Fit2 # Saves the fitnes of the solutions of the current generation.
      ranking <- nsga2R::fastNonDominatedSorting(Fit2 * -1) # NonDominatedSorting from package nsga2R. -1 multiplication to alter the sign of the fitness (function sorts from min to max).
      rnkIndex <- integer(n)
      i <- 1
      while (i <= length(ranking)) { # Save the rank of each solution.
        rnkIndex[ranking[[i]]] <- i
        i <- i + 1
      }

      X1 <- cbind(X, k, Fit2, rnkIndex) # Data.frame with solution vector, number of clusters and ranking.
      objRange <- apply(Fit2, 2, max) - apply(Fit2, 2, min) # Range of fitness of the solutions.
      CrowD <- nsga2R::crowdingDist4frnt(X1, ranking, objRange) # Crowding distance of each front (nsga2R package).
      CrowD <- apply(CrowD, 1, sum)

      X1 <- cbind(X1, CrowD) # data.frame with solution vector, number of clusters, ranking and crowding distance.

      # Output for the generation callback
      #environment(report_callback)<-environment()
      report_callback(generation=g,pop_pool=X1,pareto=PARETO,prob_matrix=prob_matrix,current_time=start_time)


      # Save parent generation.
      Xold <- X
      Nclustold <- Nclust

      # 3. create offspring.
      NEW <- offspring(X1,chrom_length,population, TournamentSize)
      X <- NEW[["New"]]
      Nclust <- NEW[["NewK"]]
    } else {
      oldnew <- rbind(PARETO[[g - 1]], Fit2)
      oldnewfeature <- rbind(Xold, X)
      oldnewNclust <- c(Nclustold, Nclust)
      oldnewK <- oldnewNclust

      ranking2 <- nsga2R::fastNonDominatedSorting(oldnew * -1) # NonDominatedSorting from package nsga2R. -1 multiplication to alter the sign of the fitness (function sorts from min to max).
      rnkIndex2 <- integer(nrow(oldnew))
      i <- 1
      while (i <= length(ranking2)) { # saves the rank of each solution.
        rnkIndex2[ranking2[[i]]] <- i
        i <- i + 1
      }


      X1 <- cbind(oldnewfeature, k = oldnewK, oldnew, rnkIndex = rnkIndex2)
      objRange <- apply(oldnew, 2, max) - apply(oldnew, 2, min) # Range of fitness of the solutions.
      CrowD <- nsga2R::crowdingDist4frnt(X1, ranking2, objRange) # Crowding distance of each front (nsga2R package).
      CrowD <- apply(CrowD, 1, sum)
      X1 <- cbind(X1, CrowD) # data.frame with solution vector, number of clusters, ranking and crowding distance
      X1 <- X1[X1[, "CrowD"] > 0, ]
      O <- order(X1[, "rnkIndex"], X1[, "CrowD"] * -1)[1:population]
      X1 <- X1[O, ]

      PARETO[[g]] <- X1[, (chrom_length + 2):(chrom_length + 3)] # Saves the fitnes of the solutions of the current generation

      # Output for the generation callback
      #environment(report_callback)<-environment()
      report_callback(generation=g,pop_pool=X1,pareto=PARETO,prob_matrix=prob_matrix,current_time=start_time)

      #print(paste0("Generation ", g, " Non-dominated solutions:"))
      #print(X1[X1[, "rnkIndex"] == 1, (chrom_length + 1):(chrom_length + 5)])

      Xold <- X1[, 1:chrom_length]
      Nclustold <- X1[, "k"]

      NEW <- offspring(X1,chrom_length,population, TournamentSize)
      X <- NEW[["New"]]
      Nclust <- NEW[["NewK"]]
    }

    # 5.Go to step 2

    gc()
    #environment(base_save_pop_callback)<-environment()
    #environment(save_pop_partial_callback)<-environment()
    save_pop_partial_callback(res_dir,generation=g,pop_pool=X1,pareto=PARETO,prob_matrix=prob_matrix,current_time=start_time)

    #environment(end_gen_callback)<-environment()
    end_gen_callback(generation=g,pop_pool=X1,pareto=PARETO,prob_matrix=prob_matrix,current_time=start_time)
  }

  parallel::stopCluster(cluster)
  #environment(base_save_pop_callback)<-environment()
  #environment(save_pop_final_callback)<-environment()
  save_pop_final_callback(res_dir,generation=g,pop_pool=X1,pareto=PARETO,prob_matrix=prob_matrix,current_time=start_time)
}

