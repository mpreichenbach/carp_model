library(momentuHMM)


fit.model <- function(.data, 
                      modelFormula,
                      factorCovs=c("Trial", "Pond", "Treatment", "Sound", "Diel"),
                      numericCovs=c("Temperature", "dB"),
                      stateNames=c("exploratory", "encamped"),
                      dist=list(step="gamma", angle="vm"),
                      initPar=list(step = c(2, 1, 1, 1), angle = c(0, 0, 0, 0))
                      ){
    
    # this ensures that covariate columns have the correct numeric/factor types
    for (factor_name in factorCovs){
        .data[[factor_name]] <- as.factor(.data[[factor_name]])
    }
    
    for (numeric_name in numericCovs){
        .data[[numeric_name]] <- as.numeric(.data[[numeric_name]])
    }

    # this logic adds zero-mass parameters, which are necessary when 0 is a step-length
    has_zero_step <- (0 %in% df$step)
    if (has_zero_step){
        zero_proportion <- length(which(.data$step == 0)) / nrow(.data)
        for (state in 1:length(stateNames)){
            initPar$step <- append(initPar$step, zero_proportion)
        }
    }
    
    # sometimes the initial parameter orders don't match the fitted parameters; this fixes that
    incorrect_means <- TRUE
    
    while (incorrect_means){
        # this section fits an initial movement model to give better starting values when fitting the full HMM.
        model_1 <- fitHMM(data=.data,
                          nbStates=length(stateNames),
                          dist=dist,
                          Par0=initPar,
                          estAngleMean=list(angle=TRUE),
                          stateNames=stateNames)
        
        print("Finished fitting movement model (step 1/3).")
        
        # this fits a model to estimate good starting transition probabilities
        initPar1 <- getPar0(model=model_1, 
                            formula=modelFormula)
        
        model_2 <- fitHMM(data=model_1$data,
                          dist=dist,
                          nbStates=length(stateNames),
                          estAngleMean=list(angle = TRUE),
                          stateNames=stateNames,
                          Par0=initPar1$Par,
                          beta0=initPar1$beta,
                          formula=modelFormula)
        
        DM <- list(step=list(mean=modelFormula, sd=~1),
                   angle=list(mean=modelFormula, concentration=~1))
        
        if (has_zero_step){DM$step$zeromass <- ~1}
        
        print("Finished fitting model for estimating initial transition probabilities (step 2/3).")
        
        # this fits the full model
        
        initPar2 <- getPar0(model=model_2,
                            formula=modelFormula,
                            DM=DM)
        
        FullModel <- fitHMM(data=model_2$data,
                            nbStates=length(stateNames),
                            dist=dist,
                            Par0=initPar2$Par,
                            beta0=initPar2$beta,
                            DM=DM,
                            stateNames=stateNames,
                            estAngleMean=list(angle = TRUE),
                            formula=modelFormula)
        
        # Makes sure that the fitted models have mean steps which align with expectations
        state_1_mean <- FullModel$CIreal$step$est[[stateNames[1]]]
        state_2_mean <- FullModel$CIreal$step$est[[stateNames[2]]]
        
        incorrect_means <- state_1_mean < state_2_mean
    }
    
    print("Finished fitting full model (step 3/3).")
    
    return(FullModel)
}

fit.model.list <- function(list_element){
    # this runs fit.model, but with a single element so that it can be entered as an argument in 
    # parallel::mclapply().
    
    hmm <- fit.model(list_element$data, 
                     modelFormula=list_elements$formula,
                     stateNames=c("exploratory", "encamped"), 
                     dist=list(step="gamma", angle="vm"),
                     initPar=list(step=c(2, 1, 1, 1), angle=c(0.004, 0.004, 0.002, 0.002)))
    
    return(hmm)
}